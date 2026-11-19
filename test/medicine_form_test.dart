import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/services/medication_voice_service.dart';
import 'package:osudsheba/features/medicines/presentation/widgets/medicine_form_parts.dart';

void main() {
  test('Drops is saved by name and reads back unchanged', () {
    final med = Medicine(
      id: 'd1',
      name: 'Optimox',
      strength: '0.5%',
      form: MedicineForm.drops,
      dose: '1',
      times: const ['08:00 AM'],
      mealRelation: 'None',
      instruction: 'Left eye',
    );
    final json = med.toJson();
    expect(json['form'], 'drops');
    expect(Medicine.fromJson(json).form, MedicineForm.drops);
  });

  test('medicines saved before Drops existed still load with their form', () {
    for (final name in ['tablet', 'capsule', 'syrup', 'injection']) {
      expect(MedicineForm.values.byName(name).name, name);
    }
  });

  group('Dose follows the medicine type', () {
    test('the default dose switches to the new type', () {
      expect(doseAfterFormChange('1 Tablet', MedicineForm.tablet, MedicineForm.drops), '1 Drop');
      expect(doseAfterFormChange('1 Drop', MedicineForm.drops, MedicineForm.syrup), '5ml');
      expect(doseAfterFormChange('5ml', MedicineForm.syrup, MedicineForm.capsule), '1 Capsule');
    });

    test('an empty dose gets the new default', () {
      expect(doseAfterFormChange('  ', MedicineForm.tablet, MedicineForm.injection), '1 ml');
    });

    test('the old injection default "1 Injection" is still treated as untouched', () {
      expect(doseAfterFormChange('1 Injection', MedicineForm.injection, MedicineForm.tablet), '1 Tablet');
    });

    test('a dose the user typed is never overwritten', () {
      expect(doseAfterFormChange('½ Tablet', MedicineForm.tablet, MedicineForm.drops), '½ Tablet');
      expect(doseAfterFormChange('2 drops', MedicineForm.drops, MedicineForm.tablet), '2 drops');
      expect(doseAfterFormChange('10 ml', MedicineForm.syrup, MedicineForm.tablet), '10 ml');
    });
  });

  group('Injection dose is an amount in ml', () {
    test('saved "2 ml" shows as "2" in the field (ml is shown after it)', () {
      expect(doseFieldText('2 ml', MedicineForm.injection), '2');
      expect(doseFieldText('0.5ml', MedicineForm.injection), '0.5');
      expect(doseFieldText('1 Injection', MedicineForm.injection), '1 Injection'); // old data shown as is
      expect(doseFieldText('2 ml', MedicineForm.syrup), '2 ml'); // other types unchanged
    });

    test('a number typed for an injection is saved with "ml"', () {
      expect(doseForSave('2', MedicineForm.injection), '2 ml');
      expect(doseForSave('1,5', MedicineForm.injection), '1.5 ml');
      expect(doseForSave('2', MedicineForm.tablet), '2');
    });

    test('switching to Injection shows the default amount as a number', () {
      expect(doseFieldAfterFormChange('1 Tablet', MedicineForm.tablet, MedicineForm.injection), '1');
      expect(doseFieldAfterFormChange('1', MedicineForm.injection, MedicineForm.drops), '1 Drop');
      expect(doseFieldAfterFormChange('3', MedicineForm.injection, MedicineForm.tablet), '3 ml');
    });
  });

  test('Drops has English and Bangla names and a spoken Bangla unit', () {
    expect(MedicineForm.drops.displayName, 'Drops');
    expect(MedicineForm.drops.bnName, 'ড্রপ');
    expect(MedicationVoiceService.formToSpokenUnit(MedicineForm.drops, '2', 'bn'), '২ ফোঁটা');
  });

  group('Custom "times a day" spreads alarms through the day', () {
    test('up to 4 times fall between 8 AM and 10 PM', () {
      expect(evenlySpacedTimes(1), ['08:00 AM']);
      expect(evenlySpacedTimes(2), ['08:00 AM', '10:00 PM']);
      expect(evenlySpacedTimes(4), ['08:00 AM', '12:30 PM', '05:30 PM', '10:00 PM']);
    });

    test('more than 4 go round the clock (6 = every 4 hours)', () {
      expect(evenlySpacedTimes(6), ['02:00 AM', '06:00 AM', '10:00 AM', '02:00 PM', '06:00 PM', '10:00 PM']);
      expect(evenlySpacedTimes(12).length, 12);
    });
  });
}
