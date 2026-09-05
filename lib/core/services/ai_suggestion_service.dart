import '../models/mock_models.dart';
import 'mock_data_service.dart';

class AiSuggestionService {

  /// Main method returning a list of suggestions.
  List<String> generateSuggestions({
    required List<Medicine> medicines,
    required List<DoseLog> doseLogs,
    required AppSettings settings,
    PatientProfile? patientProfile,
  }) {
    final String lang = settings.languageCode;

    // Return fallback suggestions derived from rules engine
    return _generateRulesFallback(
      medicines: medicines,
      doseLogs: doseLogs,
      lang: lang,
    );
  }

  /// Original rules-based suggestions generator (offline fallback)
  List<String> _generateRulesFallback({
    required List<Medicine> medicines,
    required List<DoseLog> doseLogs,
    required String lang,
  }) {
    final List<String> suggestions = [];

    if (medicines.isEmpty) {
      suggestions.add(lang == 'bn'
          ? 'নতুন ওষুধ যোগ করতে বা প্রেসক্রিপশন স্ক্যান করতে নিচে "মেনু" বা "স্ক্যান করুন" অপশন চাপুন।'
          : 'Add your medicines manually or scan a prescription to start tracking adherence.');
      return suggestions;
    }

    if (doseLogs.isEmpty) {
      suggestions.add(lang == 'bn'
          ? 'ওষুধ খাওয়ার পর তা সম্পন্ন হিসেবে চিহ্নিত করুন যেন এআই আপনার অগ্রগতি ট্র্যাক করতে পারে।'
          : 'Start marking doses as taken, skipped, or snoozed to receive personalized suggestions.');
      return suggestions;
    }

    final totalLogs = doseLogs.length;
    final takenLogs = doseLogs.where((l) => l.status.toLowerCase() == 'taken').length;

    final double adherenceRate = totalLogs > 0 ? (takenLogs / totalLogs) : 1.0;
    final int adherencePercent = (adherenceRate * 100).toInt();

    if (adherencePercent < 70) {
      suggestions.add(lang == 'bn'
          ? 'আপনার ওষুধ খাওয়ার হার খুব কম ($adherencePercent%)। অফলাইন এসএমএস রিমাইন্ডার বা পরিবারে মিসড-ডোজ অ্যালার্ট চালু করতে পারেন।'
          : 'Your adherence is low ($adherencePercent%). Consider enabling SMS reminders or caregiver alerts.');
    }

    int nightMissedOrSkipped = 0;
    for (final log in doseLogs) {
      final status = log.status.toLowerCase();
      if (status == 'missed' || status == 'skipped' || status == 'snoozed') {
        final timeStr = log.scheduledTime.toUpperCase();
        bool isNight = false;
        if (timeStr.contains('PM')) {
          final hourPart = int.tryParse(timeStr.split(':').first) ?? 0;
          if (hourPart != 12 && hourPart >= 6) {
            isNight = true;
          }
        } else if (timeStr.contains('AM')) {
          final hourPart = int.tryParse(timeStr.split(':').first) ?? 0;
          if (hourPart == 12 || hourPart < 5) {
            isNight = true;
          }
        }
        if (isNight) nightMissedOrSkipped++;
      }
    }

    if (nightMissedOrSkipped >= 2) {
      suggestions.add(lang == 'bn'
          ? 'আপনি সাধারণত রাতের ডোজগুলো ভুলে যান। রাতের ওষুধের রিমাইন্ডার সময় ৩০ মিনিট আগে সেট করে দেখুন।'
          : 'You often miss night doses. Try setting the reminder 30 minutes earlier.');
    }

    final activeMedsCount = medicines.where((m) => m.status.toLowerCase() == 'active').length;
    if (activeMedsCount >= 4) {
      suggestions.add(lang == 'bn'
          ? 'আপনার বেশ কয়েকটি সক্রিয় ওষুধ রয়েছে। কোনো ডোজ মিস হওয়া এড়াতে ওষুধ সূচিটি ভালোভাবে মিলিয়ে নিন।'
          : 'You have multiple active medicines. Review your schedule to avoid missed doses.');
    }

    if (adherencePercent >= 90) {
      suggestions.add(lang == 'bn'
          ? 'চমৎকার! আপনি নিয়মিত আপনার ওষুধ খাচ্ছেন। এই ধারাবাহিকতা বজায় রাখুন।'
          : 'Great job! You are following your medicine schedule well.');
    }

    if (suggestions.isEmpty) {
      suggestions.add(lang == 'bn'
          ? 'ওষুধ সূচি নিখুঁতভাবে মেনে চলছেন। আপনার শারীরিক সুস্থতা কামনা করি।'
          : 'Your medication compliance is stable. Keep tracking your daily routines!');
    }

    return suggestions;
  }
}
