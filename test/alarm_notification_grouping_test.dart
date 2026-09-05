import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/services/medication_voice_service.dart';
import 'package:osudsheba/core/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TEST A, B, C: Notification Time Grouping and Overview Announcements', () {
    test('TEST A: One medicine at 8:00 AM produces natural single medicine announcement', () {
      final med = Medicine(
        id: 'med_a',
        name: 'Napa',
        strength: '500mg',
        form: MedicineForm.tablet,
        dose: '1',
        times: ['08:00 AM'],
        mealRelation: 'After Meal',
        instruction: '',
        status: 'active',
      );

      final text = MedicationVoiceService.buildOverviewAnnouncement([med], lang: 'bn');

      expect(text, equals('এখন আপনার ওষুধ খাওয়ার সময় হয়েছে। এখন Napa 500 মিলিগ্রাম, ১টি ট্যাবলেট খেতে হবে।'));
      expect(text, isNot(contains('null')));
    });

    test('TEST B: Three medicines at 8:00 AM produce ONE grouped alert with all three', () {
      final med1 = Medicine(
        id: 'm1',
        name: 'Medicine A',
        strength: '500mg',
        form: MedicineForm.tablet,
        dose: '1',
        times: ['08:00 AM'],
        mealRelation: 'After Meal',
        instruction: '',
        status: 'active',
      );
      final med2 = Medicine(
        id: 'm2',
        name: 'Medicine B',
        strength: '20mg',
        form: MedicineForm.capsule,
        dose: '1',
        times: ['08:00 AM'],
        mealRelation: 'Before Meal',
        instruction: '',
        status: 'active',
      );
      final med3 = Medicine(
        id: 'm3',
        name: 'Medicine C',
        strength: '',
        form: MedicineForm.tablet,
        dose: '1',
        times: ['08:00 AM'],
        mealRelation: 'With Meal',
        instruction: '',
        status: 'active',
      );

      final grouped = NotificationService.instance.groupMedicinesByTime([med1, med2, med3]);
      expect(grouped.length, 1);
      expect(grouped['08:00 AM']!.length, 3);

      final announcement = MedicationVoiceService.buildOverviewAnnouncement([med1, med2, med3], lang: 'bn');
      expect(
        announcement,
        equals('এখন আপনার ওষুধ খাওয়ার সময় হয়েছে। এখন Medicine A, Medicine B এবং Medicine C — এই ৩টি ওষুধ খেতে হবে।'),
      );
      expect(announcement, isNot(contains('null')));
    });

    test('TEST C: Three medicines at different times produce three separate events', () {
      final medA = Medicine(
        id: 'mA',
        name: 'Medicine A',
        strength: '500mg',
        form: MedicineForm.tablet,
        dose: '1',
        times: ['08:00 AM', '08:00 PM'],
        mealRelation: 'After Meal',
        instruction: '',
        status: 'active',
      );
      final medB = Medicine(
        id: 'mB',
        name: 'Medicine B',
        strength: '20mg',
        form: MedicineForm.capsule,
        dose: '1',
        times: ['08:00 AM'],
        mealRelation: 'Before Meal',
        instruction: '',
        status: 'active',
      );
      final medC = Medicine(
        id: 'mC',
        name: 'Medicine C',
        strength: '10mg',
        form: MedicineForm.tablet,
        dose: '1',
        times: ['02:00 PM'],
        mealRelation: 'None',
        instruction: '',
        status: 'active',
      );

      final grouped = NotificationService.instance.groupMedicinesByTime([medA, medB, medC]);

      // Exactly three separate time events: 08:00 AM, 02:00 PM, 08:00 PM
      expect(grouped.length, 3);
      expect(grouped['08:00 AM']!.map((m) => m.name), containsAll(['Medicine A', 'Medicine B']));
      expect(grouped['02:00 PM']!.map((m) => m.name), containsAll(['Medicine C']));
      expect(grouped['08:00 PM']!.map((m) => m.name), containsAll(['Medicine A']));
    });
  });

  group('TEST D, E: Detailed Audio Instructions and Clean Omission', () {
    test('TEST D: Detailed instructions spoken for due medicines when audio button tapped', () {
      final med1 = Medicine(
        id: 'med_1',
        name: 'Napa',
        strength: '500mg',
        form: MedicineForm.tablet,
        dose: '1',
        times: ['08:00 AM'],
        mealRelation: 'After Meal',
        instruction: 'ভরা পেটে খাবেন',
        status: 'active',
      );
      final med2 = Medicine(
        id: 'med_2',
        name: 'Omeprazole',
        strength: '20mg',
        form: MedicineForm.capsule,
        dose: '1',
        times: ['08:00 AM'],
        mealRelation: 'Before Meal',
        instruction: '',
        status: 'active',
      );

      final detailedText = MedicationVoiceService.buildDetailedInstructions([med1, med2], lang: 'bn');

      expect(detailedText, contains('Napa 500 মিলিগ্রাম, ১টি ট্যাবলেট খাবেন।'));
      expect(detailedText, contains('খাবারের পরে খাবেন।'));
      expect(detailedText, contains('নির্দেশনা: ভরা পেটে খাবেন।'));
      expect(detailedText, contains('Omeprazole 20 মিলিগ্রাম, ১টি ক্যাপসুল খাবেন।'));
      expect(detailedText, contains('খাবারের আগে খাবেন।'));
      expect(detailedText, isNot(contains('null')));
    });

    test('TEST E: Missing strength or instruction omits fields cleanly without null or awkward spaces', () {
      final med = Medicine(
        id: 'med_no_str',
        name: 'Aspirin',
        strength: '',
        form: MedicineForm.tablet,
        dose: '1',
        times: ['08:00 AM'],
        mealRelation: 'None',
        instruction: '',
        status: 'active',
      );

      final overview = MedicationVoiceService.buildOverviewAnnouncement([med], lang: 'bn');
      expect(overview, equals('এখন আপনার ওষুধ খাওয়ার সময় হয়েছে। এখন Aspirin, ১টি ট্যাবলেট খেতে হবে।'));
      expect(overview, isNot(contains('null')));
      expect(overview, isNot(contains('  ')));

      final detailed = MedicationVoiceService.buildDetailedInstructions([med], lang: 'bn');
      expect(detailed, equals('Aspirin, ১টি ট্যাবলেট খাবেন।'));
      expect(detailed, isNot(contains('null')));
    });
  });

  group('TEST H: Voice Availability and Fallback Policy', () {
    test('Bangla voice policy does not generate English text when Bangla is requested', () {
      final med = Medicine(
        id: 'med_x',
        name: 'Napa',
        strength: '500mg',
        form: MedicineForm.tablet,
        dose: '1',
        times: ['08:00 AM'],
        mealRelation: 'After Meal',
        instruction: '',
        status: 'active',
      );

      final textBn = MedicationVoiceService.buildOverviewAnnouncement([med], lang: 'bn');
      expect(textBn, contains('এখন আপনার ওষুধ খাওয়ার সময় হয়েছে।'));
      expect(textBn, isNot(contains('It is time')));
    });

    test('TEST I: Home schedule announcement for single and grouped medicines', () {
      final medA = Medicine(
        id: 'mA',
        name: 'Napa',
        strength: '500mg',
        form: MedicineForm.tablet,
        dose: '1',
        times: ['08:00 PM'],
        mealRelation: 'After Meal',
        instruction: '',
        status: 'active',
      );
      final medB = Medicine(
        id: 'mB',
        name: 'Omeprazole',
        strength: '20mg',
        form: MedicineForm.capsule,
        dose: '1',
        times: ['08:00 PM'],
        mealRelation: 'Before Meal',
        instruction: '',
        status: 'active',
      );

      // Single medicine upcoming
      final singleUpcoming = MedicationVoiceService.buildHomeScheduleAnnouncement(
        medicines: [medA],
        scheduledTime: '08:00 PM',
        isCurrentlyDue: false,
        lang: 'bn',
      );
      expect(singleUpcoming, contains('পরবর্তী ওষুধ খাওয়ার সময় 08:00 PM।'));
      expect(singleUpcoming, contains('Napa 500 মিলিগ্রাম, ১টি ট্যাবলেট।'));
      expect(singleUpcoming, contains('খাবারের পরে খাবেন।'));

      // Grouped medicines upcoming
      final groupUpcoming = MedicationVoiceService.buildHomeScheduleAnnouncement(
        medicines: [medA, medB],
        scheduledTime: '08:00 PM',
        isCurrentlyDue: false,
        lang: 'bn',
      );
      expect(groupUpcoming, contains('পরবর্তী ওষুধ খাওয়ার সময় 08:00 PM।'));
      expect(groupUpcoming, contains('Napa এবং Omeprazole — এই ২টি ওষুধ।'));

      // Grouped medicines currently due
      final groupDue = MedicationVoiceService.buildHomeScheduleAnnouncement(
        medicines: [medA, medB],
        scheduledTime: '08:00 PM',
        isCurrentlyDue: true,
        lang: 'bn',
      );
      expect(groupDue, contains('এখন আপনার ওষুধ খাওয়ার সময় হয়েছে।'));
      expect(groupDue, contains('Napa এবং Omeprazole — এই ২টি ওষুধ।'));

      // Empty medicines
      final emptyText = MedicationVoiceService.buildHomeScheduleAnnouncement(
        medicines: [],
        scheduledTime: null,
        lang: 'bn',
      );
      expect(emptyText, equals('এই সময়ের জন্য কোনো ওষুধ নির্ধারিত নেই।'));
    });
  });
}
