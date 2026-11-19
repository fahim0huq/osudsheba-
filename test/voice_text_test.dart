// What the reminder voice actually says, with doses as the app saves them ("1 Tablet", "5ml").
import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/services/medication_voice_service.dart';

Medicine _med(MedicineForm form, String dose, {String strength = '500mg'}) => Medicine(
      id: 'm',
      name: 'Napa',
      strength: strength,
      form: form,
      dose: dose,
      times: const ['08:00 PM'],
      mealRelation: 'After Meal',
      instruction: '',
    );

void main() {
  group('saved doses are spoken once, not doubled', () {
    test('Bangla', () {
      String bn(MedicineForm f, String d) => MedicationVoiceService.formToSpokenUnit(f, d, 'bn');
      expect(bn(MedicineForm.tablet, '1 Tablet'), '১টি ট্যাবলেট');
      expect(bn(MedicineForm.tablet, '2'), '২টি ট্যাবলেট');
      expect(bn(MedicineForm.tablet, '১টি ট্যাবলেট'), '১টি ট্যাবলেট');
      expect(bn(MedicineForm.capsule, '1 Capsule'), '১টি ক্যাপসুল');
      expect(bn(MedicineForm.syrup, '5ml'), '৫ মিলিলিটার সিরাপ');
      expect(bn(MedicineForm.syrup, '2'), '২ চামচ সিরাপ');
      expect(bn(MedicineForm.injection, '2 ml'), '২ মিলিলিটার ইনজেকশন');
      expect(bn(MedicineForm.drops, '2 Drops'), '২ ফোঁটা');
      expect(bn(MedicineForm.tablet, ''), '১টি ট্যাবলেট');
    });

    test('English', () {
      String en(MedicineForm f, String d) => MedicationVoiceService.formToSpokenUnit(f, d, 'en');
      expect(en(MedicineForm.tablet, '1 Tablet'), '1 tablet');
      expect(en(MedicineForm.tablet, '2 Tablets'), '2 tablets');
      expect(en(MedicineForm.syrup, '5ml'), '5 ml of syrup');
      expect(en(MedicineForm.drops, '1 Drop'), '1 drop');
      expect(en(MedicineForm.tablet, 'half tablet'), 'half tablet');
    });
  });

  test('times are spoken the way people say them', () {
    expect(MedicationVoiceService.spokenTime('08:00 AM', 'bn'), 'সকাল ৮টায়');
    expect(MedicationVoiceService.spokenTime('02:30 PM', 'bn'), 'দুপুর ২টা ৩০ মিনিটে');
    expect(MedicationVoiceService.spokenTime('09:00 PM', 'bn'), 'রাত ৯টায়');
    expect(MedicationVoiceService.spokenTime('08:00 PM', 'en'), '8 PM');
    expect(MedicationVoiceService.spokenTime('08:30 AM', 'en'), '8:30 AM');
  });

  test('Home announcement has no raw "08:00 PM" or doubled units', () {
    final bn = MedicationVoiceService.buildHomeScheduleAnnouncement(
        medicines: [_med(MedicineForm.tablet, '1 Tablet')], scheduledTime: '08:00 PM', lang: 'bn');
    expect(bn, contains('রাত ৮টায়'));
    expect(bn, contains('১টি ট্যাবলেট'));
    expect(bn, isNot(contains('Tablet')));
    expect(bn, isNot(contains('PM')));

    final en = MedicationVoiceService.buildHomeScheduleAnnouncement(
        medicines: [_med(MedicineForm.tablet, '1 Tablet')], scheduledTime: '08:00 PM', lang: 'en');
    expect(en, 'Your next scheduled medicine is at 8 PM. You need to take: Napa 500 milligrams, 1 tablet.');
  });

  test('when today is done, the announcement says so and names tomorrow', () {
    final bn = MedicationVoiceService.buildHomeScheduleAnnouncement(
        medicines: [_med(MedicineForm.tablet, '1')], scheduledTime: '08:00 AM', isTomorrow: true, lang: 'bn');
    expect(bn, contains('আগামীকাল সকাল ৮টায়'));
    final en = MedicationVoiceService.buildHomeScheduleAnnouncement(
        medicines: [_med(MedicineForm.tablet, '1')], scheduledTime: '08:00 AM', isTomorrow: true, lang: 'en');
    expect(en, startsWith('All doses for today are done. Your next medicine is tomorrow at 8 AM.'));
  });
}
