// The reminder style setting and the medicine photo survive saving and loading.
import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';

void main() {
  test('full-screen alarm is the default and is saved', () {
    expect(AppSettings().fullScreenAlarms, isTrue);
    expect(AppSettings.fromJson(const {}).fullScreenAlarms, isTrue); // settings saved before this option
    final off = AppSettings().copyWith(fullScreenAlarms: false);
    expect(AppSettings.fromJson(off.toJson()).fullScreenAlarms, isFalse);
  });

  test('medicine photo path is saved, kept by copyWith, and can be removed', () {
    final m = Medicine(
      id: 'm1',
      name: 'Napa',
      strength: '500mg',
      form: MedicineForm.tablet,
      dose: '1',
      times: const ['08:00 AM'],
      mealRelation: 'After Meal',
      instruction: '',
      photoPath: '/data/photos/napa.jpg',
    );
    expect(Medicine.fromJson(m.toJson()).photoPath, '/data/photos/napa.jpg');
    expect(m.copyWith(name: 'Napa Extra').photoPath, '/data/photos/napa.jpg');
    expect(m.copyWith(clearPhoto: true).photoPath, isNull);
    expect(Medicine.fromJson(m.copyWith(clearPhoto: true).toJson()).photoPath, isNull);
  });
}
