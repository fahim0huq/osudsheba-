import '../models/mock_models.dart';
import 'time_utils.dart';

/// Pure scheduling helpers shared by alarms, the home screen and adherence tracking.
/// Kept free of Flutter/plugin imports so they can be unit tested directly.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Statuses that mean "this dose has been dealt with" (no more alarm needed).
const Set<String> handledDoseStatuses = {'taken', 'late', 'skipped'};

extension MedicineScheduleX on Medicine {
  bool get isActive => status.toLowerCase() == 'active';

  /// True when the medicine is active and [day] falls within its start/end dates.
  bool isScheduledOn(DateTime day) {
    if (!isActive) return false;
    final d = dateOnly(day);
    if (startDate != null && d.isBefore(dateOnly(startDate!))) return false;
    if (endDate != null && d.isAfter(dateOnly(endDate!))) return false;
    return true;
  }
}

/// True if a dose log for [medicineId] at [slot] exists on [day] with one of [statuses].
bool hasDoseLog(
  List<DoseLog> logs,
  String medicineId,
  String slot,
  DateTime day, {
  Set<String> statuses = handledDoseStatuses,
}) {
  return logs.any((l) =>
      l.medicineId == medicineId &&
      sameTimeOfDay(l.scheduledTime, slot) &&
      l.actualTime != null &&
      isSameDay(l.actualTime!, day) &&
      statuses.contains(l.status.toLowerCase()));
}

/// A scheduled dose that was neither taken nor skipped in time.
class MissedDose {
  final Medicine medicine;
  final String slot; // canonical "hh:mm AM"
  final DateTime scheduledAt;
  const MissedDose(this.medicine, this.slot, this.scheduledAt);
}

/// Finds doses whose time passed more than [grace] ago without a taken/late/skipped/missed
/// log for that slot and day. Looks back [lookbackDays] days (including today)
/// and never before the medicine was added, so adding a medicine at 3 PM does not flag
/// that morning's 8 AM dose as missed.
List<MissedDose> findMissedDoses({
  required List<Medicine> medicines,
  required List<DoseLog> logs,
  required DateTime now,
  Duration grace = const Duration(minutes: 60),
  int lookbackDays = 2,
}) {
  final result = <MissedDose>[];
  final today = dateOnly(now);
  for (var offset = lookbackDays - 1; offset >= 0; offset--) {
    final day = today.subtract(Duration(days: offset));
    for (final med in medicines) {
      if (!med.isScheduledOn(day)) continue;
      for (final rawSlot in med.times) {
        final t = parseTimeOfDay(rawSlot);
        if (t == null) continue;
        final scheduledAt = DateTime(day.year, day.month, day.day, t.hour, t.minute);
        if (now.difference(scheduledAt) < grace) continue; // not overdue yet (or in the future)
        // Never flag doses scheduled before the medicine existed in the app.
        final since = med.createdAt ?? med.startDate;
        if (since == null) {
          if (!isSameDay(day, today)) continue; // unknown creation time: only judge today
        } else if (scheduledAt.isBefore(since)) {
          continue;
        }
        // A "snoozed" log alone does not count: snoozing and then never taking it is a miss.
        final resolved = hasDoseLog(logs, med.id, rawSlot, day,
            statuses: const {'taken', 'late', 'skipped', 'missed'});
        if (!resolved) {
          result.add(MissedDose(med, formatTimeOfDay(t.hour, t.minute), scheduledAt));
        }
      }
    }
  }
  return result;
}

/// Today's status label for a medicine across all of its times:
/// "Taken" only once every dose due today is taken (or the rest skipped), so a
/// three-times-a-day medicine does not show "Taken" after the morning dose.
String todayStatusFor(Medicine med, List<DoseLog> logs, DateTime now) {
  if (!med.isScheduledOn(now)) {
    return med.isActive ? 'Not today' : med.status;
  }
  final slots = med.times;
  if (slots.isEmpty) return 'Pending';
  bool all(String st) => slots.every((t) => hasDoseLog(logs, med.id, t, now, statuses: {st}));
  bool any(String st) => slots.any((t) => hasDoseLog(logs, med.id, t, now, statuses: {st}));
  final handledAll = slots.every((t) => hasDoseLog(logs, med.id, t, now));
  if (all('taken') || (handledAll && any('taken'))) return 'Taken';
  if (all('skipped')) return 'Skipped';
  if (any('missed')) return 'Missed';
  if (any('snoozed')) return 'Snoozed';
  return 'Pending';
}
