import '../services/medication_voice_service.dart';
import 'time_utils.dart';

/// Short on-screen labels for times, waits and meals, in the viewer's language.
/// Pure Dart so they can be unit tested.

/// "08:00 PM" -> "8:00 PM" (English) or "রাত ৮:০০" (Bangla, with the part of the day).
String displayTime(String time, String lang) {
  final minute = minutesOfDay(time);
  if (minute < 0) return time;
  final h = minute ~/ 60, m = minute % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  final mm = m.toString().padLeft(2, '0');
  if (lang != 'bn') return '$h12:$mm ${h < 12 ? 'AM' : 'PM'}';
  return MedicationVoiceService.toBanglaDigits('${dayPart(h)} $h12:$mm');
}

/// Bangla part of the day for an hour 0-23 (same bands as the spoken reminders).
String dayPart(int hour) {
  if (hour < 4) return 'রাত';
  if (hour < 6) return 'ভোর';
  if (hour < 12) return 'সকাল';
  if (hour < 15) return 'দুপুর';
  if (hour < 18) return 'বিকাল';
  if (hour < 20) return 'সন্ধ্যা';
  return 'রাত';
}

/// "2 h 20 min" / "২ ঘণ্টা ২০ মিনিট". Under a minute counts as one minute.
String durationLabel(Duration d, String lang) {
  final total = d.inMinutes < 1 ? 1 : d.inMinutes;
  final h = total ~/ 60, m = total % 60;
  if (lang == 'bn') {
    final parts = [if (h > 0) '$h ঘণ্টা', if (m > 0) '$m মিনিট'];
    return MedicationVoiceService.toBanglaDigits(parts.join(' '));
  }
  return [if (h > 0) '$h h', if (m > 0) '$m min'].join(' ');
}

/// "in 20 min" / "২০ মিনিট পরে".
String inLabel(Duration d, String lang) =>
    lang == 'bn' ? '${durationLabel(d, lang)} পরে' : 'in ${durationLabel(d, lang)}';

/// "30 min late" / "৩০ মিনিট দেরি".
String lateLabel(Duration d, String lang) =>
    lang == 'bn' ? '${durationLabel(d, lang)} দেরি' : '${durationLabel(d, lang)} late';

/// Saved meal relation ("After Meal") as a short label; empty for "None".
String mealLabel(String meal, String lang) {
  final clean = meal.trim();
  if (clean.isEmpty || clean == 'None') return '';
  if (lang != 'bn') return clean[0] + clean.substring(1).toLowerCase();
  return const {'Before Meal': 'খাবারের আগে', 'After Meal': 'খাবারের পরে', 'With Meal': 'খাবারের সাথে'}[clean] ??
      clean;
}

/// Bangla digits in Bangla, unchanged in English.
String localDigits(Object n, String lang) =>
    lang == 'bn' ? MedicationVoiceService.toBanglaDigits('$n') : '$n';

/// Shown instead of Taken / Skip before a dose's time has come.
String notYetText(String time, String lang) => lang == 'bn'
    ? '${displayTime(time, lang)} হলে খেয়েছি চাপতে পারবেন'
    : 'You can mark it as taken from ${displayTime(time, lang)}';
