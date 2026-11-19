// The dose shown on screen is in the viewer's language (Bangla screens used to show "1 Tablet").
import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/utils/dose_text.dart';

Medicine _med(MedicineForm form, String dose) => Medicine(
      id: 'm',
      name: 'Napa',
      strength: '500mg',
      form: form,
      dose: dose,
      times: const ['08:00 PM'],
      mealRelation: 'After Meal',
      instruction: '',
    );

void main() {
  test('Bangla screens show the dose in Bangla', () {
    expect(doseLabel(_med(MedicineForm.tablet, '1 Tablet'), 'bn'), '১টি ট্যাবলেট');
    expect(doseLabel(_med(MedicineForm.capsule, '2'), 'bn'), '২টি ক্যাপসুল');
    expect(doseLabel(_med(MedicineForm.syrup, '5 ml'), 'bn'), '৫ মিলিলিটার সিরাপ');
    expect(doseLabel(_med(MedicineForm.drops, '3 Drops'), 'bn'), '৩ ফোঁটা');
  });

  test('English keeps typed text and adds a unit to a bare number', () {
    expect(doseLabel(_med(MedicineForm.tablet, '1 Tablet'), 'en'), '1 Tablet');
    expect(doseLabel(_med(MedicineForm.tablet, '2'), 'en'), '2 tablets');
    expect(doseLabel(_med(MedicineForm.syrup, '1 spoon'), 'en'), '1 spoon');
  });

  test('an empty dose stays empty instead of inventing "1 tablet"', () {
    expect(doseLabel(_med(MedicineForm.tablet, ''), 'bn'), '');
    expect(doseLabel(_med(MedicineForm.tablet, '  '), 'en'), '');
  });
}
