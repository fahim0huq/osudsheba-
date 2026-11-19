import '../models/mock_models.dart';
import 'schedule_utils.dart';
import 'time_utils.dart';

/// What a caregiver sees for one dose today.
enum DoseState { taken, skipped, missed, dueNow, upcoming }

class DayDose {
  const DayDose(this.medicine, this.slot, this.at, this.state);
  final Medicine medicine;
  final String slot; // "hh:mm AM"
  final DateTime at;
  final DoseState state;
}

/// A dose counts as "due now" from this long before its time...
const Duration kDueEarly = Duration(minutes: 30);

/// ...until this long after it; later and still not recorded, it is missed (same grace as
/// the app's own missed-dose marking).
const Duration kMissedAfter = Duration(minutes: 60);

/// Every dose due on [now]'s day, sorted by time, with its state. Doses scheduled before
/// the medicine was added are left out (they were never expected).
List<DayDose> dosesForDay({required List<Medicine> medicines, required List<DoseLog> logs, required DateTime now}) {
  final out = <DayDose>[];
  for (final med in medicines) {
    if (!med.isScheduledOn(now)) continue;
    for (final raw in med.times) {
      final t = parseTimeOfDay(raw);
      if (t == null) continue;
      final at = DateTime(now.year, now.month, now.day, t.hour, t.minute);
      final since = med.createdAt;
      if (since != null && at.isBefore(since)) continue;
      out.add(DayDose(med, formatTimeOfDay(t.hour, t.minute), at, _state(med, raw, at, logs, now)));
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

DoseState _state(Medicine med, String slot, DateTime at, List<DoseLog> logs, DateTime now) {
  bool logged(Set<String> statuses) => hasDoseLog(logs, med.id, slot, now, statuses: statuses);
  if (logged(const {'taken', 'late'})) return DoseState.taken;
  if (logged(const {'skipped'})) return DoseState.skipped;
  if (logged(const {'missed'})) return DoseState.missed;
  // Not recorded (or only snoozed): judge by the clock.
  if (now.isAfter(at.add(kMissedAfter))) return DoseState.missed;
  if (!now.isBefore(at.subtract(kDueEarly))) return DoseState.dueNow;
  return DoseState.upcoming;
}

/// Taken share of decided doses (taken, skipped, missed) for each of the last [days] days,
/// oldest first; null for a day with nothing decided.
List<int?> dailyAdherence({required List<DoseLog> logs, required DateTime now, int days = 7}) {
  final result = <int?>[];
  for (var i = days - 1; i >= 0; i--) {
    final key = dateKey(dateOnly(now).subtract(Duration(days: i)));
    final dayLogs = logs.where((l) => l.effectiveScheduledDate == key);
    final taken = dayLogs.where((l) => l.status == 'taken' || l.status == 'late').length;
    final decided = dayLogs.where((l) => const {'taken', 'late', 'skipped', 'missed'}.contains(l.status)).length;
    result.add(decided == 0 ? null : (taken * 100 / decided).round());
  }
  return result;
}
