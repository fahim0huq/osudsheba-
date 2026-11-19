import '../models/mock_models.dart';
import 'schedule_utils.dart';

/// Caregiver alert text in the viewer's language, built when shown.
///
/// Alerts used to be saved as finished English sentences ("Missed Dose: Napa",
/// "Today, 08:00 AM"), so Bangla users saw English, and "Today" stayed "Today" on
/// later days. Older alerts without [CaregiverAlert.kind] are read back from their id and
/// English text.

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
String _digits(String s, bool bn) =>
    bn ? s.replaceAllMapped(RegExp(r'\d'), (m) => _bnDigits[int.parse(m[0]!)]) : s;

String? _kind(CaregiverAlert a) {
  if (a.kind != null) return a.kind;
  if (a.id == 'no_medicines_alert') return 'no_medicines';
  if (a.id.startsWith('missed_')) return 'missed_dose';
  return null;
}

String? _medicine(CaregiverAlert a) {
  if (a.medicineName != null) return a.medicineName;
  const prefix = 'Missed Dose: ';
  return a.title.startsWith(prefix) ? a.title.substring(prefix.length) : null;
}

String? _slot(CaregiverAlert a) =>
    a.scheduledTime ?? RegExp(r'scheduled at (.+?) was').firstMatch(a.message)?.group(1);

DateTime? _when(CaregiverAlert a) {
  if (a.occurredAt != null) return a.occurredAt;
  // Older missed-dose ids end with the dose's date and time: missed_missed_<med>_<ISO time>.
  final iso = RegExp(r'(\d{4}-\d{2}-\d{2}T[\d:.]+)$').firstMatch(a.id)?.group(1);
  return iso == null ? null : DateTime.tryParse(iso);
}

String alertTitleText(CaregiverAlert a, String lang) {
  final bn = lang == 'bn';
  switch (_kind(a)) {
    case 'missed_dose':
      final name = _medicine(a) ?? '';
      return bn ? 'ডোজ মিস হয়েছে: $name' : 'Missed dose: $name';
    case 'no_medicines':
      return bn ? 'কোনো চালু ওষুধ নেই' : 'No active medicines';
  }
  return a.title;
}

String alertMessageText(CaregiverAlert a, String lang) {
  final bn = lang == 'bn';
  switch (_kind(a)) {
    case 'missed_dose':
      final name = _medicine(a) ?? '';
      final slot = _slot(a) ?? '';
      return bn
          ? '$slot-এর $name এক ঘণ্টার মধ্যে খাওয়া হয়েছে বলে চিহ্নিত করা হয়নি।'
          : '$name due at $slot was not marked as taken within an hour.';
    case 'no_medicines':
      return bn ? 'রোগীর তালিকায় কোনো চালু ওষুধ নেই।' : 'The patient has no active medicines in their schedule.';
  }
  return a.message;
}

/// "Today, 08:00 AM" / "আজ, 08:00 AM", worked out from the date, so it is right on later days.
String alertTimeText(CaregiverAlert a, String lang, DateTime now) {
  final bn = lang == 'bn';
  final when = _when(a);
  if (when == null) return _kind(a) == null ? a.time : '';
  final String day;
  if (isSameDay(when, now)) {
    day = bn ? 'আজ' : 'Today';
  } else if (isSameDay(when, now.subtract(const Duration(days: 1)))) {
    day = bn ? 'গতকাল' : 'Yesterday';
  } else {
    day = _digits('${when.day}/${when.month}/${when.year}', bn);
  }
  final slot = _kind(a) == 'missed_dose' ? _slot(a) : null;
  return slot == null ? day : '$day, $slot';
}

String alertSeverityText(CaregiverAlert a, String lang) {
  if (lang != 'bn') return a.severity.toUpperCase();
  return const {'High': 'জরুরি', 'Medium': 'মাঝারি', 'Low': 'সাধারণ'}[a.severity] ?? a.severity;
}
