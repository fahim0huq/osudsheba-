/// Helpers for the "hh:mm AM/PM" time strings used throughout OsudSheba.
///
/// Every scheduled time is stored as a canonical string such as "08:00 AM".
/// Alarm scheduling, the reminder screen and adherence logs all match on that
/// exact string, so anything typed by a user or returned by the AI parser must be
/// normalised before it is saved. A time that cannot be understood would
/// otherwise be stored silently and the alarm would never ring.
library;

const _bnDigits = {
  '০': '0', '১': '1', '২': '2', '৩': '3', '৪': '4',
  '৫': '5', '৬': '6', '৭': '7', '৮': '8', '৯': '9',
};

/// Parses a time string into (hour 0-23, minute). Returns null if it cannot be understood.
///
/// Accepts: "8:00 AM", "08:00am", "8 PM", "8pm", "20:00", "20.30", "0800",
/// and Bangla digits (e.g. "৮:০০ PM").
({int hour, int minute})? parseTimeOfDay(String? input) {
  if (input == null) return null;
  var s = input.trim();
  if (s.isEmpty) return null;
  _bnDigits.forEach((bn, en) => s = s.replaceAll(bn, en));
  s = s.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
  // "a.m." / "p.m." first, then treat any remaining dot as the hour:minute separator.
  s = s.replaceAllMapped(RegExp(r'([AP])\.?\s?M\.?'), (m) => '${m[1]}M');
  s = s.replaceAll('.', ':');

  final m = RegExp(r'^(\d{1,2})(?::?(\d{2}))?\s*(AM|PM)?$').firstMatch(s);
  if (m == null) return null;

  var hour = int.parse(m.group(1)!);
  final minute = m.group(2) != null ? int.parse(m.group(2)!) : 0;
  final ampm = m.group(3);

  if (minute > 59) return null;
  if (ampm != null) {
    if (hour < 1 || hour > 12) return null;
    if (ampm == 'PM' && hour < 12) hour += 12;
    if (ampm == 'AM' && hour == 12) hour = 0;
  } else {
    // 24-hour clock without AM/PM. A bare "8" is ambiguous, so require minutes
    // or an hour that can only be 24h (13-23) or 0.
    if (hour > 23) return null;
    if (m.group(2) == null && hour >= 1 && hour <= 12) return null;
  }
  return (hour: hour, minute: minute);
}

/// Formats an hour/minute into the canonical "hh:mm AM" form, e.g. "08:00 AM".
String formatTimeOfDay(int hour, int minute) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final ampm = hour < 12 ? 'AM' : 'PM';
  return '${h12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $ampm';
}

/// Returns the canonical form of [input], or null if it cannot be understood.
String? normalizeTimeString(String? input) {
  final t = parseTimeOfDay(input);
  return t == null ? null : formatTimeOfDay(t.hour, t.minute);
}

/// Normalises a list of times: canonical form, duplicates removed, sorted by time of day.
/// Unparseable entries are dropped; use [invalidTimes] to find them first.
List<String> normalizeTimeList(Iterable<String> times) {
  final out = <String>{};
  for (final t in times) {
    final n = normalizeTimeString(t);
    if (n != null) out.add(n);
  }
  final list = out.toList()..sort((a, b) => minutesOfDay(a).compareTo(minutesOfDay(b)));
  return list;
}

/// Entries in [times] that cannot be understood as a time of day.
List<String> invalidTimes(Iterable<String> times) =>
    times.where((t) => t.trim().isNotEmpty && parseTimeOfDay(t) == null).toList();

/// Minutes since midnight for a time string, or -1 if unparseable.
int minutesOfDay(String time) {
  final t = parseTimeOfDay(time);
  return t == null ? -1 : t.hour * 60 + t.minute;
}

/// True when two time strings refer to the same time of day ("8:00 AM" == "08:00 AM").
bool sameTimeOfDay(String a, String b) {
  final ma = minutesOfDay(a);
  return ma >= 0 && ma == minutesOfDay(b);
}
