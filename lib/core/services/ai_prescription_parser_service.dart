import 'dart:developer' as dev;
import 'package:uuid/uuid.dart';
import '../models/mock_models.dart';

class AiPrescriptionParserService {
  /// Track if the service had to fall back to the offline regex parser
  bool usedFallback = false;

  /// Main extraction entry point
  Future<List<Medicine>> parsePrescriptionText(String rawText) async {
    usedFallback = true;
    return _parseOfflineFallback(rawText);
  }

  /// Labelled offline degraded fallback parser (original Regex)
  List<Medicine> _parseOfflineFallback(String rawText) {
    dev.log('AiPrescriptionParserService: Running offline regex fallback parser.');
    final List<Medicine> medicines = [];
    final lines = rawText.split('\n');

    final List<String> commonNames = [
      'napa', 'seclo', 'metformin', 'amoxicillin', 'montair', 
      'paracetamol', 'ace', 'gliclazide', 'atorvastatin', 
      'losartan', 'omeprazole', 'pantoprazole', 'esomeprazole'
    ];

    for (final line in lines) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;

      String name = '';
      String strength = '';
      MedicineForm form = MedicineForm.tablet;
      String dose = '1 Tablet';
      List<String> reminderTimes = ['08:00 AM'];
      String mealRelation = 'After Meal';
      String instruction = '';
      int days = 7;

      final cleanLower = cleanLine.toLowerCase();

      for (final common in commonNames) {
        if (cleanLower.contains(common)) {
          name = common[0].toUpperCase() + common.substring(1);
          break;
        }
      }

      if (name.isEmpty) {
        final words = cleanLine.split(RegExp(r'\s+'));
        if (words.isNotEmpty && words[0].length > 2) {
          name = words[0];
          name = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        } else {
          continue;
        }
      }

      if (name.isEmpty || name.length <= 2) continue;

      if (cleanLower.contains('capsule') || cleanLower.contains('cap')) {
        form = MedicineForm.capsule;
        dose = '1 Capsule';
      } else if (cleanLower.contains('syrup') || cleanLower.contains('syp') || cleanLower.contains('ml')) {
        form = MedicineForm.syrup;
        dose = '5ml';
      } else if (cleanLower.contains('injection') || cleanLower.contains('inj')) {
        form = MedicineForm.injection;
        dose = '1 Injection';
      } else {
        form = MedicineForm.tablet;
        dose = '1 Tablet';
      }

      final strengthMatch = RegExp(r'\b(\d+)\s*(mg|ml|g)\b', caseSensitive: false).firstMatch(cleanLine);
      if (strengthMatch != null) {
        strength = strengthMatch.group(0) ?? '';
      } else {
        strength = form == MedicineForm.syrup ? '100ml' : '500mg';
      }

      final freqMatch = RegExp(r'\b([0-9])\+([0-9])\+([0-9])\b').firstMatch(cleanLine);
      if (freqMatch != null) {
        final m = int.tryParse(freqMatch.group(1) ?? '0') ?? 0;
        final a = int.tryParse(freqMatch.group(2) ?? '0') ?? 0;
        final n = int.tryParse(freqMatch.group(3) ?? '0') ?? 0;

        reminderTimes = [];
        if (m > 0) reminderTimes.add('08:00 AM');
        if (a > 0) reminderTimes.add('02:00 PM');
        if (n > 0) reminderTimes.add('08:00 PM');

        if (reminderTimes.isEmpty) {
          reminderTimes.add('08:00 AM');
        }
      } else {
        if (cleanLower.contains('twice') || cleanLower.contains('2 times')) {
          reminderTimes = ['08:00 AM', '08:00 PM'];
        } else if (cleanLower.contains('three') || cleanLower.contains('3 times')) {
          reminderTimes = ['08:00 AM', '02:00 PM', '08:00 PM'];
        } else if (cleanLower.contains('once') || cleanLower.contains('daily')) {
          reminderTimes = ['08:00 AM'];
        }
      }

      if (cleanLower.contains('before breakfast') || cleanLower.contains('before meal') || cleanLower.contains('empty stomach')) {
        mealRelation = 'Before Meal';
      } else if (cleanLower.contains('after meal') || cleanLower.contains('after breakfast')) {
        mealRelation = 'After Meal';
      } else if (cleanLower.contains('with meal')) {
        mealRelation = 'With Meal';
      }

      final durationMatch = RegExp(r'\b(\d+)\s*(day|days|din|দিন)\b', caseSensitive: false).firstMatch(cleanLine);
      if (durationMatch != null) {
        days = int.tryParse(durationMatch.group(1) ?? '7') ?? 7;
      }

      instruction = '$cleanLine (Offline Regex Fallback)';

      final now = DateTime.now();
      medicines.add(Medicine(
        id: const Uuid().v4(),
        name: name,
        strength: strength,
        form: form,
        dose: dose,
        times: reminderTimes,
        mealRelation: mealRelation,
        instruction: instruction,
        startDate: now,
        endDate: now.add(Duration(days: days)),
        status: 'active',
        createdAt: now,
      ));
    }

    return medicines;
  }
}
