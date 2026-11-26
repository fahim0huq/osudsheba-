import 'time_utils.dart';

/// The six daily dose times, the way Bangladeshi prescriptions are written
/// ("1+0+1, after meal" = morning and night, after eating).
///
/// A medicine can use any of these instead of its own clock times. Every medicine in a slot
/// shares the slot's time, which the person sets once (Reminder settings), so there is ONE
/// reminder per slot ("Morning, after meal: 3 medicines") instead of one per medicine.
/// Medicines needing exact times (every 4 hours, 6/8 times a day) use custom times instead.
enum DoseSlot { morningBefore, morningAfter, noonBefore, noonAfter, nightBefore, nightAfter }

enum DayPart { morning, noon, night }

extension DoseSlotX on DoseSlot {
  /// Stored in Medicine.slots and AppSettings.slotTimes: never rename.
  String get key => const {
        DoseSlot.morningBefore: 'morning_before',
        DoseSlot.morningAfter: 'morning_after',
        DoseSlot.noonBefore: 'noon_before',
        DoseSlot.noonAfter: 'noon_after',
        DoseSlot.nightBefore: 'night_before',
        DoseSlot.nightAfter: 'night_after',
      }[this]!;

  bool get beforeMeal => index.isEven;

  DayPart get part => DayPart.values[index ~/ 2];

  /// Default clock time, changeable in Reminder settings.
  String get defaultTime => const {
        DoseSlot.morningBefore: '07:30 AM',
        DoseSlot.morningAfter: '08:30 AM',
        DoseSlot.noonBefore: '01:00 PM',
        DoseSlot.noonAfter: '02:00 PM',
        DoseSlot.nightBefore: '08:30 PM',
        DoseSlot.nightAfter: '09:30 PM',
      }[this]!;

  String mealLabel(bool bn) =>
      beforeMeal ? (bn ? 'খাবারের আগে' : 'before meal') : (bn ? 'খাবারের পরে' : 'after meal');

  /// "Morning · after meal" / "সকাল · খাবারের পরে".
  String label(bool bn) => '${part.label(bn)} · ${mealLabel(bn)}';
}

extension DayPartX on DayPart {
  String label(bool bn) => switch (this) {
        DayPart.morning => bn ? 'সকাল' : 'Morning',
        DayPart.noon => bn ? 'দুপুর' : 'Noon',
        DayPart.night => bn ? 'রাত' : 'Night',
      };
}

DoseSlot? slotFromKey(String key) {
  for (final s in DoseSlot.values) {
    if (s.key == key) return s;
  }
  return null;
}

/// The slots in a stored list of keys (unknown keys are ignored), in day order.
List<DoseSlot> slotsFromKeys(Iterable<String> keys) =>
    DoseSlot.values.where((s) => keys.contains(s.key)).toList();

/// The clock time of [slot]: the person's own setting, or the default.
String slotTime(DoseSlot slot, Map<String, String> slotTimes) =>
    normalizeTimeString(slotTimes[slot.key]) ?? slot.defaultTime;

/// Reminder times for these slots, sorted and without duplicates (two slots set to the
/// same time share one reminder).
List<String> timesForSlots(Iterable<DoseSlot> slots, Map<String, String> slotTimes) {
  final times = {for (final s in slots) slotTime(s, slotTimes)}.toList();
  times.sort((a, b) => minutesOfDay(a).compareTo(minutesOfDay(b)));
  return times;
}

/// Medicine.mealRelation for these slots: before / after when all agree, otherwise "None"
/// (the slot itself then tells before or after).
String mealRelationForSlots(List<DoseSlot> slots) {
  if (slots.isEmpty) return 'None';
  if (slots.every((s) => s.beforeMeal)) return 'Before Meal';
  if (slots.every((s) => !s.beforeMeal)) return 'After Meal';
  return 'None';
}

/// The slot whose time is [time], for labelling a reminder or a list ("Morning · after
/// meal"); null for a custom time.
DoseSlot? slotAtTime(String time, Map<String, String> slotTimes) {
  for (final s in DoseSlot.values) {
    if (sameTimeOfDay(slotTime(s, slotTimes), time)) return s;
  }
  return null;
}
