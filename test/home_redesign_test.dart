// Labels and per-dose states behind the new Home and Today's medicines screens.
import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/utils/home_schedule.dart';
import 'package:osudsheba/core/utils/time_label.dart';

final _day = DateTime(2026, 11, 24);

Medicine _med(String id, List<String> times, {String status = 'active'}) => Medicine(
      id: id,
      name: 'Med $id',
      strength: '10mg',
      form: MedicineForm.tablet,
      dose: '1 Tablet',
      times: times,
      mealRelation: 'After Meal',
      instruction: '',
      status: status,
      startDate: _day.subtract(const Duration(days: 3)),
      createdAt: _day.subtract(const Duration(days: 3)),
    );

DoseLog _log(String id, String time, String status) => DoseLog(
      id: 'l$id$time',
      medicineId: id,
      medicineName: id,
      scheduledTime: time,
      actualTime: _day.add(const Duration(hours: 9)),
      status: status,
    );

void main() {
  test('times read naturally in both languages', () {
    expect(displayTime('08:00 PM', 'en'), '8:00 PM');
    expect(displayTime('08:00 PM', 'bn'), 'রাত ৮:০০');
    expect(displayTime('02:30 PM', 'bn'), 'দুপুর ২:৩০');
    expect(displayTime('07:00 AM', 'bn'), 'সকাল ৭:০০');
    expect(displayTime('06:15 PM', 'bn'), 'সন্ধ্যা ৬:১৫');
  });

  test('waits: "in 20 min", "1 h 5 min late", in Bangla too', () {
    expect(inLabel(const Duration(minutes: 20), 'en'), 'in 20 min');
    expect(inLabel(const Duration(minutes: 140), 'bn'), '২ ঘণ্টা ২০ মিনিট পরে');
    expect(lateLabel(const Duration(minutes: 65), 'en'), '1 h 5 min late');
    expect(lateLabel(const Duration(minutes: 60), 'bn'), '১ ঘণ্টা দেরি');
    expect(inLabel(const Duration(seconds: 20), 'en'), 'in 1 min');
  });

  test('meal labels', () {
    expect(mealLabel('After Meal', 'en'), 'After meal');
    expect(mealLabel('Before Meal', 'bn'), 'খাবারের আগে');
    expect(mealLabel('None', 'bn'), '');
  });

  test('todayDoses: one row per medicine and time, with what was recorded', () {
    final meds = [
      _med('a', ['08:00 AM', '08:00 PM']),
      _med('b', ['08:00 AM', '02:00 PM']),
      _med('p', ['08:00 AM'], status: 'paused'),
    ];
    final logs = [_log('a', '08:00 AM', 'taken'), _log('b', '08:00 AM', 'skipped'), _log('b', '02:00 PM', 'missed')];
    final doses = todayDoses(medicines: meds, logs: logs, now: _day.add(const Duration(hours: 15)));
    expect(doses.map((d) => '${d.medicine.id} ${d.time} ${d.state.name}').toList(), [
      'a 08:00 AM taken',
      'b 08:00 AM skipped',
      'b 02:00 PM missed',
      'a 08:00 PM pending',
    ]);
  });

  test('a dose can only be recorded once its time has come', () {
    final now = DateTime(2026, 11, 24, 14, 10); // 2:10 PM
    expect(doseTimeHasCome('02:00 PM', now), isTrue);
    expect(doseTimeHasCome('02:10 PM', now), isTrue);
    expect(doseTimeHasCome('02:30 PM', now), isFalse);
    expect(doseTimeHasCome('not a time', now), isFalse);
    expect(notYetText('02:30 PM', 'en'), 'You can mark it as taken from 2:30 PM');
    expect(notYetText('02:30 PM', 'bn'), 'দুপুর ২:৩০ হলে খেয়েছি চাপতে পারবেন');
  });
}
