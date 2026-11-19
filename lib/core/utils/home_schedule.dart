import '../models/mock_models.dart';
import 'schedule_utils.dart';
import 'time_utils.dart';

/// Pure helpers behind the Home screen: the "Next dose" card, the "not recorded yet"
/// list and today's progress. Kept free of Flutter so they can be unit tested with a
/// fixed clock.

/// One time slot (e.g. "08:00 PM") and the medicines due in it.
class DoseSlot {
  final String time; // canonical "hh:mm AM"
  final DateTime scheduledAt;
  final List<Medicine> medicines;

  /// True when nothing is left today and this is tomorrow's first dose.
  final bool isTomorrow;

  const DoseSlot({
    required this.time,
    required this.scheduledAt,
    required this.medicines,
    this.isTomorrow = false,
  });
}

/// Every unhandled slot on [day] for medicines scheduled that day, earliest first.
/// [include] decides, by minute of the day, which slots count.
List<DoseSlot> _slotsOn(
  List<Medicine> medicines,
  List<DoseLog> logs,
  DateTime day, {
  required bool Function(int minute) include,
  Set<String> handled = handledDoseStatuses,
  bool isTomorrow = false,
}) {
  final byMinute = <int, List<Medicine>>{};
  for (final med in medicines) {
    if (!med.isScheduledOn(day)) continue;
    final seen = <int>{};
    for (final t in med.times) {
      final m = minutesOfDay(t);
      if (m < 0 || !include(m) || !seen.add(m)) continue;
      if (hasDoseLog(logs, med.id, t, day, statuses: handled)) continue;
      byMinute.putIfAbsent(m, () => []).add(med);
    }
  }
  final minutes = byMinute.keys.toList()..sort();
  return [
    for (final m in minutes)
      DoseSlot(
        time: formatTimeOfDay(m ~/ 60, m % 60),
        scheduledAt: DateTime(day.year, day.month, day.day, m ~/ 60, m % 60),
        medicines: byMinute[m]!,
        isTomorrow: isTomorrow,
      ),
  ];
}

/// The next dose still to take: the earliest slot later today that has not been taken,
/// skipped or marked missed. When nothing is left today it returns tomorrow's first slot
/// with [DoseSlot.isTomorrow] set, so the card can say "All done for today" instead of
/// showing a dose that was already taken. Returns null when nothing is scheduled.
DoseSlot? findNextDose({
  required List<Medicine> medicines,
  required List<DoseLog> logs,
  required DateTime now,
}) {
  final nowMinute = now.hour * 60 + now.minute;
  final today = _slotsOn(medicines, logs, now,
      include: (m) => m > nowMinute, handled: const {...handledDoseStatuses, 'missed'});
  if (today.isNotEmpty) return today.first;
  final tomorrow = dateOnly(now).add(const Duration(days: 1));
  final next = _slotsOn(medicines, const [], tomorrow, include: (_) => true, isTomorrow: true);
  return next.isEmpty ? null : next.first;
}

/// Slots whose time has come today but that were not taken or skipped yet, earliest first.
/// A dose auto-marked "missed" is still listed, so it can be recorded if it was taken.
List<DoseSlot> findOverdueToday({
  required List<Medicine> medicines,
  required List<DoseLog> logs,
  required DateTime now,
}) {
  final nowMinute = now.hour * 60 + now.minute;
  return _slotsOn(medicines, logs, now, include: (m) => m <= nowMinute);
}

/// Doses taken today (on time or late) and doses scheduled today.
({int taken, int total}) todayDoseCounts({
  required List<Medicine> medicines,
  required List<DoseLog> logs,
  required DateTime now,
}) {
  var taken = 0, total = 0;
  for (final med in medicines) {
    if (!med.isScheduledOn(now)) continue;
    final seen = <int>{};
    for (final t in med.times) {
      final m = minutesOfDay(t);
      if (m < 0 || !seen.add(m)) continue;
      total++;
      if (hasDoseLog(logs, med.id, t, now, statuses: const {'taken', 'late'})) taken++;
    }
  }
  return (taken: taken, total: total);
}
