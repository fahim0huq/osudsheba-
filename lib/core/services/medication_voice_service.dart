import '../models/mock_models.dart';
import '../utils/time_utils.dart';

class MedicationVoiceService {
  const MedicationVoiceService._();

  /// Converts English numeric digits (0-9) to standard Bengali digits (০-৯).
  static String toBanglaDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    String result = input;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], bangla[i]);
    }
    return result;
  }

  /// Cleans and formats the strength string for speech (e.g. "500mg" -> "500 মিলিগ্রাম").
  static String formatStrengthForSpeech(String rawStrength, String lang) {
    final trimmed = rawStrength.trim();
    if (trimmed.isEmpty) return '';

    if (lang == 'bn') {
      return trimmed
          .replaceAll(RegExp(r'mg', caseSensitive: false), ' মিলিগ্রাম')
          .replaceAll(RegExp(r'ml', caseSensitive: false), ' মিলিলিটার')
          .trim();
    } else {
      return trimmed
          .replaceAll(RegExp(r'\s*mg\b', caseSensitive: false), ' milligrams')
          .replaceAll(RegExp(r'\s*ml\b', caseSensitive: false), ' millilitres')
          .trim();
    }
  }

  static final _doseAmount = RegExp(r'^([0-9০-৯]+(?:[.,/][0-9০-৯]+)?|½)\s*(.*)$');

  /// Converts the dose and medicine form to spoken words (e.g. "১টি ট্যাবলেট", "5 ml of syrup").
  ///
  /// Saved doses usually carry their own unit ("1 Tablet", "5ml", "2 Drops"), so only the
  /// number is kept and the unit is spoken once. (Before, "1 Tablet" was spoken as
  /// "১ Tabletটি ট্যাবলেট" in Bangla and "1 Tablet Tablet" in English.) Doses without a
  /// leading number ("half tablet") are spoken as written.
  static String formToSpokenUnit(MedicineForm form, String dose, String lang) {
    final clean = dose.trim();
    final m = _doseAmount.firstMatch(clean);
    if (clean.isNotEmpty && m == null) return lang == 'bn' ? toBanglaDigits(clean) : clean;
    final amount = (m?.group(1) ?? '1').replaceAll(',', '.');
    final unit = (m?.group(2) ?? '').toLowerCase();
    final isMl = unit.contains('ml') || unit.contains('মিলি');
    final one = amount == '1' || amount == '১';
    if (lang == 'bn') {
      final n = amount == '½' ? 'আধা' : toBanglaDigits(amount);
      switch (form) {
        case MedicineForm.tablet:
          return '$nটি ট্যাবলেট';
        case MedicineForm.capsule:
          return '$nটি ক্যাপসুল';
        case MedicineForm.syrup:
          return isMl ? '$n মিলিলিটার সিরাপ' : '$n চামচ সিরাপ';
        case MedicineForm.injection:
          return isMl ? '$n মিলিলিটার ইনজেকশন' : '$n ইনজেকশন';
        case MedicineForm.drops:
          return '$n ফোঁটা';
      }
    }
    final n = amount == '½' ? 'half' : amount;
    switch (form) {
      case MedicineForm.tablet:
        return one ? '1 tablet' : '$n tablets';
      case MedicineForm.capsule:
        return one ? '1 capsule' : '$n capsules';
      case MedicineForm.syrup:
        return isMl ? '$n ml of syrup' : (one ? '1 spoon of syrup' : '$n spoons of syrup');
      case MedicineForm.injection:
        return isMl ? '$n ml injection' : (one ? '1 injection' : '$n injections');
      case MedicineForm.drops:
        return one ? '1 drop' : '$n drops';
    }
  }

  /// A time the voice can read naturally: "08:30 PM" -> "রাত ৮টা ৩০ মিনিটে" in Bangla
  /// (instead of "zero eight colon three zero P M") or "8:30 PM" in English.
  static String spokenTime(String time, String lang) {
    final t = parseTimeOfDay(time);
    if (t == null) return time;
    final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    if (lang != 'bn') {
      final ampm = t.hour < 12 ? 'AM' : 'PM';
      return t.minute == 0 ? '$h12 $ampm' : '$h12:${t.minute.toString().padLeft(2, '0')} $ampm';
    }
    final h = t.hour;
    final String part;
    if (h < 4) {
      part = 'রাত';
    } else if (h < 6) {
      part = 'ভোর';
    } else if (h < 12) {
      part = 'সকাল';
    } else if (h < 15) {
      part = 'দুপুর';
    } else if (h < 18) {
      part = 'বিকাল';
    } else if (h < 20) {
      part = 'সন্ধ্যা';
    } else {
      part = 'রাত';
    }
    final hour = toBanglaDigits('$h12');
    return t.minute == 0
        ? '$part $hourটায়'
        : '$part $hourটা ${toBanglaDigits('${t.minute}')} মিনিটে';
  }

  /// Converts the meal relation string to natural spoken Bengali or English.
  static String localizeMealForSpeech(String mealRelation, String lang) {
    final clean = mealRelation.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'none') return '';

    if (lang == 'bn') {
      switch (clean) {
        case 'Before Meal':
          return 'খাবারের আগে খাবেন।';
        case 'After Meal':
          return 'খাবারের পরে খাবেন।';
        case 'With Meal':
          return 'খাবারের সাথে খাবেন।';
        default:
          return '$clean খাবেন।';
      }
    } else {
      switch (clean) {
        case 'Before Meal':
          return 'Take before meal.';
        case 'After Meal':
          return 'Take after meal.';
        case 'With Meal':
          return 'Take with meal.';
        default:
          return 'Take $clean.';
      }
    }
  }

  /// Builds the automatic overview announcement when a scheduled medication time is reached.
  ///
  /// Single medicine example:
  /// "এখন আপনার ওষুধ খাওয়ার সময় হয়েছে। এখন Napa 500 মিলিগ্রাম, ১টি ট্যাবলেট খেতে হবে।"
  /// (If strength is missing: "এখন আপনার ওষুধ খাওয়ার সময় হয়েছে। এখন Napa, ১টি ট্যাবলেট খেতে হবে।")
  ///
  /// Multiple medicines example:
  /// "এখন আপনার ওষুধ খাওয়ার সময় হয়েছে। এখন Napa, Omeprazole এবং Ceevit — এই ৩টি ওষুধ খেতে হবে।"
  static String buildOverviewAnnouncement(List<Medicine> medicines, {String lang = 'bn'}) {
    if (medicines.isEmpty) return '';

    if (lang == 'bn') {
      if (medicines.length == 1) {
        final med = medicines.first;
        final strengthSpoken = formatStrengthForSpeech(med.strength, 'bn');
        final unitSpoken = formToSpokenUnit(med.form, med.dose, 'bn');

        final nameAndStrength = strengthSpoken.isNotEmpty
            ? '${med.name} $strengthSpoken'
            : med.name;

        return 'এখন আপনার ওষুধ খাওয়ার সময় হয়েছে। এখন $nameAndStrength, $unitSpoken খেতে হবে।';
      } else {
        final names = medicines.map((m) => m.name.trim()).where((n) => n.isNotEmpty).toList();
        String joinedNames = '';
        if (names.length == 2) {
          joinedNames = '${names[0]} এবং ${names[1]}';
        } else if (names.length > 2) {
          final allButLast = names.sublist(0, names.length - 1).join(', ');
          joinedNames = '$allButLast এবং ${names.last}';
        } else if (names.length == 1) {
          joinedNames = names.first;
        }

        final countBn = toBanglaDigits(medicines.length.toString());
        return 'এখন আপনার ওষুধ খাওয়ার সময় হয়েছে। এখন $joinedNames — এই $countBnটি ওষুধ খেতে হবে।';
      }
    } else {
      if (medicines.length == 1) {
        final med = medicines.first;
        final strength = formatStrengthForSpeech(med.strength, 'en');
        final nameAndStrength = strength.isNotEmpty ? '${med.name} $strength' : med.name;
        final unit = formToSpokenUnit(med.form, med.dose, 'en');
        return 'It is time to take your medicine. Please take $nameAndStrength, $unit now.';
      } else {
        final names = medicines.map((m) => m.name.trim()).where((n) => n.isNotEmpty).toList();
        final joinedNames = names.length == 2 ? '${names[0]} and ${names[1]}' : names.join(', ');
        return 'It is time to take your medicines. Please take your medicine now. $joinedNames — these ${medicines.length} medicines need to be taken now.';
      }
    }
  }

  /// Builds detailed medication instructions spoken when the user taps [ 🔊 শুনুন ].
  ///
  /// Example:
  /// "Napa 500 মিলিগ্রাম, ১টি ট্যাবলেট খাবেন। খাবারের পরে খাবেন। Omeprazole 20 মিলিগ্রাম, ১টি ক্যাপসুল খাবেন। খাবারের আগে খাবেন।"
  static String buildDetailedInstructions(List<Medicine> medicines, {String lang = 'bn'}) {
    if (medicines.isEmpty) return '';

    final buffer = StringBuffer();

    if (lang == 'bn') {
      for (int i = 0; i < medicines.length; i++) {
        final med = medicines[i];
        final strengthSpoken = formatStrengthForSpeech(med.strength, 'bn');
        final unitSpoken = formToSpokenUnit(med.form, med.dose, 'bn');

        final medPrefix = strengthSpoken.isNotEmpty
            ? '${med.name} $strengthSpoken, $unitSpoken খাবেন।'
            : '${med.name}, $unitSpoken খাবেন।';

        buffer.write('$medPrefix ');

        final mealSpeech = localizeMealForSpeech(med.mealRelation, 'bn');
        if (mealSpeech.isNotEmpty) {
          buffer.write('$mealSpeech ');
        }

        final instruction = med.instruction.trim();
        if (instruction.isNotEmpty && instruction.toLowerCase() != 'null') {
          buffer.write('নির্দেশনা: $instruction। ');
        }
      }
    } else {
      for (int i = 0; i < medicines.length; i++) {
        final med = medicines[i];
        final strength = formatStrengthForSpeech(med.strength, 'en');
        final unit = formToSpokenUnit(med.form, med.dose, 'en');

        final medPrefix = strength.isNotEmpty
            ? '${med.name} $strength, $unit.'
            : '${med.name}, $unit.';

        buffer.write('$medPrefix ');

        final mealSpeech = localizeMealForSpeech(med.mealRelation, 'en');
        if (mealSpeech.isNotEmpty) {
          buffer.write('$mealSpeech ');
        }

        final instruction = med.instruction.trim();
        if (instruction.isNotEmpty && instruction.toLowerCase() != 'null') {
          buffer.write('Note: $instruction. ');
        }
      }
    }

    return buffer.toString().trim();
  }

  /// Builds the Home screen announcement for current or upcoming scheduled medications.
  ///
  /// Scenarios:
  /// 1. If currently due:
  ///    "এখন আপনার ওষুধ খাওয়ার সময় হয়েছে। আপনাকে খেতে হবে: Napa 500 মিলিগ্রাম, ১টি ট্যাবলেট।"
  /// 2. If upcoming:
  ///    "পরবর্তী ওষুধ খাওয়ার সময় রাত ৮টায়। আপনাকে খেতে হবে: Napa 500 মিলিগ্রাম, ১টি ট্যাবলেট।"
  /// 3. If today's doses are all done ([isTomorrow]): says so, then tomorrow's first dose.
  /// 4. If no medicines scheduled:
  ///    "এই সময়ের জন্য কোনো ওষুধ নির্ধারিত নেই।"
  static String buildHomeScheduleAnnouncement({
    required List<Medicine> medicines,
    required String? scheduledTime,
    bool isCurrentlyDue = false,
    bool isTomorrow = false,
    String lang = 'bn',
  }) {
    if (medicines.isEmpty || scheduledTime == null) {
      return lang == 'bn'
          ? 'এই সময়ের জন্য কোনো ওষুধ নির্ধারিত নেই।'
          : 'No medicines scheduled at this time.';
    }

    final buffer = StringBuffer();

    if (lang == 'bn') {
      if (isCurrentlyDue) {
        buffer.write('এখন আপনার ওষুধ খাওয়ার সময় হয়েছে। ');
      } else {
        final when = spokenTime(scheduledTime, 'bn');
        buffer.write(isTomorrow
            ? 'আজকের সব ওষুধ খাওয়া শেষ। পরবর্তী ওষুধ আগামীকাল $when। '
            : 'পরবর্তী ওষুধ খাওয়ার সময় $when। ');
      }

      if (medicines.length == 1) {
        final med = medicines.first;
        final strengthSpoken = formatStrengthForSpeech(med.strength, 'bn');
        final unitSpoken = formToSpokenUnit(med.form, med.dose, 'bn');
        final nameAndStrength = strengthSpoken.isNotEmpty
            ? '${med.name} $strengthSpoken'
            : med.name;

        buffer.write('আপনাকে খেতে হবে: $nameAndStrength, $unitSpoken।');

        final mealSpeech = localizeMealForSpeech(med.mealRelation, 'bn');
        if (mealSpeech.isNotEmpty) {
          buffer.write(' $mealSpeech');
        }
      } else {
        final names = medicines.map((m) => m.name.trim()).where((n) => n.isNotEmpty).toList();
        String joinedNames = '';
        if (names.length == 2) {
          joinedNames = '${names[0]} এবং ${names[1]}';
        } else if (names.length > 2) {
          final allButLast = names.sublist(0, names.length - 1).join(', ');
          joinedNames = '$allButLast এবং ${names.last}';
        } else if (names.length == 1) {
          joinedNames = names.first;
        }

        final countBn = toBanglaDigits(medicines.length.toString());
        buffer.write('আপনাকে খেতে হবে: $joinedNames — এই $countBnটি ওষুধ।');
      }
    } else {
      if (isCurrentlyDue) {
        buffer.write('It is time for your medicine. ');
      } else {
        final when = spokenTime(scheduledTime, 'en');
        buffer.write(isTomorrow
            ? 'All doses for today are done. Your next medicine is tomorrow at $when. '
            : 'Your next scheduled medicine is at $when. ');
      }

      if (medicines.length == 1) {
        final med = medicines.first;
        final strength = formatStrengthForSpeech(med.strength, 'en');
        final nameAndStrength = strength.isNotEmpty ? '${med.name} $strength' : med.name;
        final unit = formToSpokenUnit(med.form, med.dose, 'en');
        buffer.write('You need to take: $nameAndStrength, $unit.');
      } else {
        final names = medicines.map((m) => m.name.trim()).where((n) => n.isNotEmpty).toList();
        final joinedNames = names.length == 2 ? '${names[0]} and ${names[1]}' : names.join(', ');
        buffer.write('You need to take: $joinedNames (${medicines.length} medicines).');
      }
    }

    return buffer.toString().trim();
  }
}
