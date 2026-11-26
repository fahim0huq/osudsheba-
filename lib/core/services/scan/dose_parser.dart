import '../../models/mock_models.dart';
import '../../utils/dose_slots.dart';
import '../../utils/time_utils.dart';

/// What a prescription says about how to take one medicine.
class DoseInfo {
  /// Parts of the day from "1+0+1", "BD", "রাতে"...: saved as meal-time slots.
  final List<DayPart> parts;

  /// Exact clock times, only for schedules that are not morning/noon/night: every 6 or 8
  /// hours, 4 or more times a day, or times written on the prescription ("10 pm").
  final List<String> times;
  final String? dose; // null = use the form's default
  final String? mealRelation; // 'Before Meal' | 'After Meal' | 'With Meal'
  final int? durationDays; // null = not written (or "continue")
  final bool continuing; // "চলবে" / "continue"
  final String? pattern; // the notation found, e.g. "1+0+1" or "BD"

  const DoseInfo({
    this.parts = const [],
    this.times = const [],
    this.dose,
    this.mealRelation,
    this.durationDays,
    this.continuing = false,
    this.pattern,
  });

  bool get hasTiming => parts.isNotEmpty || times.isNotEmpty;

  /// The meal-time slots: the part of the day, and before or after meal (after when the
  /// prescription does not say, as most Bangladeshi prescriptions mean).
  List<DoseSlot> get slots => [
    for (final p in parts) DoseSlot.values[p.index * 2 + (mealRelation == 'Before Meal' ? 0 : 1)],
  ];
}

/// Clock times for [count] doses evenly spread over 24 hours from 6 AM (every 6 hours = 4).
List<String> intervalTimes(int count) =>
    [for (var i = 0; i < count; i++) formatTimeOfDay((6 + i * 24 ~/ count) % 24, 0)]
      ..sort((a, b) => minutesOfDay(a).compareTo(minutesOfDay(b)));

const _bnDigits = '০১২৩৪৫৬৭৮৯';

/// Bangla digits to ASCII, so "১+০+১" reads like "1+0+1".
String asciiDigits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final i = _bnDigits.indexOf(String.fromCharCode(r));
    b.write(i >= 0 ? '$i' : String.fromCharCode(r));
  }
  return b.toString();
}

// One slot of "1+0+1": a digit, ½ or 1/2. Separators: + - – (OCR often reads + as -).
const _slot = r'(½|1/2|[0-9])';
final _slotsRe = RegExp(
  '(?<![0-9/.])$_slot\\s*[+\\-–]\\s*$_slot\\s*[+\\-–]\\s*$_slot(?:\\s*[+\\-–]\\s*$_slot)?(?![0-9/])',
);

final _countWords = <RegExp, int>{
  RegExp(r'\b(qds|qid|4\s*times|four\s*times)\b|দিনে\s*4\s*বার', caseSensitive: false): 4,
  RegExp(r'\b(tds|tid|thrice|3\s*times|three\s*times)\b|দিনে\s*3\s*বার', caseSensitive: false): 3,
  RegExp(r'\b(bd|bid|twice|2\s*times|two\s*times)\b|দিনে\s*2\s*বার', caseSensitive: false): 2,
  RegExp(r'\b(od|once(\s*daily)?|1\s*time|daily)\b|দিনে\s*1\s*বার', caseSensitive: false): 1,
};
final _partWords = <DayPart, RegExp>{
  DayPart.morning: RegExp(r'\bmorning\b|সকাল', caseSensitive: false),
  DayPart.noon: RegExp(r'\b(noon|lunch)\b|দুপুর', caseSensitive: false),
  DayPart.night: RegExp(r'\b(hs|night|bed\s*time|bedtime)\b|রাত|ঘুমানোর', caseSensitive: false),
};
final _interval = RegExp(
  r'\bq\s*(\d{1,2})\s*h\b|every\s*(\d{1,2})\s*(?:hours?|hrs?)\b|\b(\d{1,2})\s*(?:hourly|hrly)\b|(\d{1,2})\s*ঘণ্টা\s*পর\s*পর',
  caseSensitive: false,
);
final _clock = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b', caseSensitive: false);

final _before = RegExp(
  r'before\s*(meal|food|breakfast|lunch|dinner)|\ba\.?c\.?\b|empty\s*stomach|(খাবার|খাওয়া|খাওয়া)\S*\s*(আগে|পূর্বে)|খালি\s*পেটে',
  caseSensitive: false,
);
final _after = RegExp(
  r'after\s*(meal|food|breakfast|lunch|dinner)|\bp\.?c\.?\b|(খাবার|খাওয়া|খাওয়া)\S*\s*(পরে|পর)|ভরা\s*পেটে',
  caseSensitive: false,
);
final _with = RegExp(r'with\s*(meal|food)|(খাবার|খাওয়া|খাওয়া)\S*\s*(সাথে|সঙ্গে)', caseSensitive: false);

final _days = RegExp(r'(\d+)\s*(?:d|day|days|din|দিন)\b|(\d+)\s*দিন', caseSensitive: false);
final _weeks = RegExp(r'(\d+)\s*(?:wk|wks|week|weeks)\b|(\d+)\s*সপ্তাহ', caseSensitive: false);
final _months = RegExp(r'(\d+)\s*(?:mo|mon|month|months)\b|(\d+)\s*মাস', caseSensitive: false);
final _continue = RegExp(r'\bcont(inue|\.)?\b|চলবে|চালিয়ে|long\s*term', caseSensitive: false);

final _spoons = RegExp(r'(½|1/2|\d+(?:\.\d+)?)\s*(?:tsf|tsp|spoons?|চামচ)', caseSensitive: false);
final _mlAmount = RegExp(r'(?<![/\d])(\d+(?:\.\d+)?)\s*ml\b(?!\s*/)', caseSensitive: false);
final _unitAmount = RegExp(r'(?<![\d./])(½|1/2|\d)\s*(?:tabs?|tablets?|caps?|capsules?|টি|টা)', caseSensitive: false);
final _dropsAmount = RegExp(r'(\d+)\s*(?:drops?|gtts?|ফোঁটা)', caseSensitive: false);

double _slotValue(String s) => (s == '½' || s == '1/2') ? 0.5 : double.parse(s);

String _num(double v) => v == 0.5 ? '½' : (v == v.roundToDouble() ? v.toInt().toString() : v.toString());

String _countDose(double n, MedicineForm form) {
  switch (form) {
    case MedicineForm.tablet:
      return '${_num(n)} ${n > 1 ? 'Tablets' : 'Tablet'}';
    case MedicineForm.capsule:
      return '${_num(n)} ${n > 1 ? 'Capsules' : 'Capsule'}';
    case MedicineForm.syrup:
      return '${_num(n * 5)}ml'; // in BD, "2+0+2" for syrup means teaspoons (5 ml each)
    case MedicineForm.drops:
      return '${_num(n)} ${n > 1 ? 'Drops' : 'Drop'}';
    case MedicineForm.injection:
      return form.defaultDose;
  }
}

/// Exact times written on the prescription ("8 am, 10:30 pm"), or an interval ("q6h",
/// "every 8 hours", "৬ ঘণ্টা পর পর"). Empty when neither is written.
(List<String>, String?) _exactTimes(String t) {
  final interval = _interval.firstMatch(t);
  if (interval != null) {
    final h = int.parse([1, 2, 3, 4].map(interval.group).firstWhere((g) => g != null)!);
    if (h > 0 && h <= 12 && 24 % h == 0) return (intervalTimes(24 ~/ h), interval.group(0)!.trim());
  }
  final clocks = [
    for (final m in _clock.allMatches(t))
      if (int.parse(m.group(1)!) case final hr when hr >= 1 && hr <= 12)
        formatTimeOfDay(hr % 12 + (m.group(3)!.toLowerCase() == 'pm' ? 12 : 0), int.tryParse(m.group(2) ?? '') ?? 0),
  ];
  if (clocks.isEmpty) return (const [], null);
  return (normalizeTimeList(clocks), _clock.allMatches(t).map((m) => m.group(0)!.trim()).join(', '));
}

/// Reads dose notation from [text] (a medicine line plus the lines under it).
/// [strengthText] is removed first so "120 mg/5 ml" is not read as a 5 ml dose.
DoseInfo parseDose(String text, MedicineForm form, {String strengthText = ''}) {
  var t = asciiDigits(text);
  if (strengthText.isNotEmpty) t = t.replaceAll(strengthText, ' ');

  var (times, pattern) = _exactTimes(t);
  var parts = <DayPart>[];
  String? dose;
  final slots = _slotsRe.firstMatch(t);
  if (slots != null) {
    pattern ??= slots.group(0)!.replaceAll(RegExp(r'\s'), '');
    final values = [
      for (var i = 1; i <= 4; i++)
        if (slots.group(i) != null) _slotValue(slots.group(i)!),
    ];
    if (times.isEmpty) {
      if (values.length == 4) {
        final four = intervalTimes(4);
        times = [
          for (var i = 0; i < 4; i++)
            if (values[i] > 0) four[i],
        ];
      } else {
        parts = [
          for (var i = 0; i < 3; i++)
            if (values[i] > 0) DayPart.values[i],
        ];
      }
    }
    final first = values.firstWhere((v) => v > 0, orElse: () => 0);
    if (first > 0) dose = _countDose(first, form);
  } else if (times.isEmpty) {
    for (final e in _countWords.entries) {
      final m = e.key.firstMatch(t);
      if (m == null) continue;
      pattern = m.group(0)!.trim();
      switch (e.value) {
        case 1:
          parts = [DayPart.morning];
        case 2:
          parts = [DayPart.morning, DayPart.night];
        case 3:
          parts = DayPart.values.toList();
        default:
          times = intervalTimes(e.value);
      }
      break;
    }
    // "সকালে ও রাতে", "at night": the words name the parts of the day. They override a
    // vague count ("once daily at night" = night).
    final named = [
      for (final e in _partWords.entries)
        if (e.value.hasMatch(t)) e.key,
    ];
    if (named.isNotEmpty && times.isEmpty && (parts.length <= 1 || parts.length == named.length)) {
      pattern ??= _partWords[named.first]!.firstMatch(t)!.group(0);
      parts = named;
    }
  }

  if (form == MedicineForm.syrup) {
    final sp = _spoons.firstMatch(t);
    final ml = _mlAmount.firstMatch(t);
    if (sp != null) {
      dose = '${_num(_slotValue(sp.group(1)!) * 5)}ml';
    } else if (ml != null) {
      dose = '${ml.group(1)}ml';
    }
  } else if (form == MedicineForm.drops) {
    final d = _dropsAmount.firstMatch(t);
    if (d != null) dose = _countDose(double.parse(d.group(1)!), form);
  } else if (form == MedicineForm.injection) {
    final ml = _mlAmount.firstMatch(t);
    if (ml != null) dose = '${ml.group(1)} ml';
  } else if (dose == null) {
    final u = _unitAmount.firstMatch(t);
    if (u != null) dose = _countDose(_slotValue(u.group(1)!), form);
  }

  String? meal;
  if (_before.hasMatch(t)) {
    meal = 'Before Meal';
  } else if (_after.hasMatch(t)) {
    meal = 'After Meal';
  } else if (_with.hasMatch(t)) {
    meal = 'With Meal';
  }

  int? grab(RegExp re, int mult) {
    final m = re.firstMatch(t);
    if (m == null) return null;
    final n = int.tryParse(m.group(1) ?? m.group(2) ?? '');
    return (n == null || n == 0) ? null : n * mult;
  }

  final days = grab(_days, 1) ?? grab(_weeks, 7) ?? grab(_months, 30);
  final continuing = days == null && _continue.hasMatch(t);

  return DoseInfo(
    parts: parts,
    times: times,
    dose: dose,
    mealRelation: meal,
    durationDays: days,
    continuing: continuing,
    pattern: pattern,
  );
}
