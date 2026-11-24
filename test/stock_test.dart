// Medicine stock: what is left, when it runs out, how much to buy, when to remind.
import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/utils/stock.dart';

final _set = DateTime(2026, 11, 20, 9); // stock counted at 9 AM on 20 Nov
final _now = DateTime(2026, 11, 24, 8); // 8 AM on 24 Nov

Medicine _med({
  double? stock = 20,
  String dose = '1 Tablet',
  List<String> times = const ['08:00 AM', '08:00 PM'],
  MedicineForm form = MedicineForm.tablet,
  DateTime? end,
  String status = 'active',
}) => Medicine(
  id: 'm',
  name: 'Napa',
  strength: '500mg',
  form: form,
  dose: dose,
  times: times,
  mealRelation: 'After Meal',
  instruction: '',
  status: status,
  endDate: end,
  stockCount: stock,
  stockSetAt: stock == null ? null : _set,
);

DoseLog _log(DateTime at, {String status = 'taken', String id = 'm'}) => DoseLog(
  id: 'l$at$id',
  medicineId: id,
  medicineName: 'Napa',
  scheduledTime: '08:00 AM',
  actualTime: at,
  status: status,
);

void main() {
  test('dose amounts are read from the dose text', () {
    expect(doseAmount('1 Tablet'), 1);
    expect(doseAmount('½ Tablet'), 0.5);
    expect(doseAmount('1/2'), 0.5);
    expect(doseAmount('5ml'), 5);
    expect(doseAmount('২টি'), 2);
    expect(doseAmount('some'), 1);
  });

  test('taken doses since the count are used up; skipped and earlier ones are not', () {
    final logs = [
      _log(DateTime(2026, 11, 19, 20)), // before the count
      _log(DateTime(2026, 11, 21, 8)),
      _log(DateTime(2026, 11, 21, 20)),
      _log(DateTime(2026, 11, 22, 8), status: 'skipped'),
      _log(DateTime(2026, 11, 22, 20), status: 'late'),
      _log(DateTime(2026, 11, 22, 21), id: 'other'),
    ];
    final s = stockStatus(_med(), logs, _now)!;
    expect(s.left, 17);
    expect(s.perDay, 2);
    expect(s.daysLeft, 8);
    expect(s.runsOutOn, DateTime(2026, 12, 2));
    expect(s.low, isFalse);
  });

  test('low within the alert days, empty when less than one dose is left', () {
    final logs = [for (var i = 0; i < 13; i++) _log(DateTime(2026, 11, 21, 8, i))];
    final low = stockStatus(_med(), logs, _now, alertDays: 5)!;
    expect(low.left, 7);
    expect(low.daysLeft, 3);
    expect(low.low, isTrue);
    expect(low.needsBuying, isTrue);
    final empty = stockStatus(_med(stock: 0.5), const [], _now)!;
    expect(empty.empty, isTrue);
    expect(empty.left, 0.5);
  });

  test('no buy alert when the course ends before the stock runs out', () {
    final s = stockStatus(_med(stock: 6, end: DateTime(2026, 11, 25)), const [], _now)!;
    expect(s.courseEndsFirst, isTrue);
    expect(s.low, isFalse);
    expect(refillReminderTimes(s, _now), isEmpty);
  });

  test('paused medicines and drops are not counted down', () {
    expect(stockStatus(_med(status: 'paused'), const [], _now)!.daysLeft, isNull);
    expect(stockStatus(_med(form: MedicineForm.drops), const [], _now), isNull);
    expect(stockStatus(_med(stock: null), const [], _now), isNull);
  });

  test('suggested purchase: 30 days in whole strips, or until the course ends; ml as is', () {
    final s = stockStatus(_med(stock: 7), const [], _now)!;
    final buy = suggestedPurchase(_med(stock: 7), s, _now);
    expect(buy.days, 30);
    expect(buy.amount, 60); // 60 - 7 = 53 -> 6 strips
    final course = _med(stock: 4, end: DateTime(2026, 12, 3));
    final cs = stockStatus(course, const [], _now)!;
    expect(suggestedPurchase(course, cs, _now).amount, 20); // 10 days * 2 - 4 = 16 -> 20
    final syrup = _med(stock: 20, dose: '5ml', form: MedicineForm.syrup, times: const ['08:00 AM']);
    final ss = stockStatus(syrup, const [], _now)!;
    expect(suggestedPurchase(syrup, ss, _now).amount, 130);
  });

  test('reminders at 10 AM from the day stock gets low until it runs out', () {
    final s = stockStatus(_med(stock: 14), const [], _now)!; // 7 days -> runs out 1 Dec
    final times = refillReminderTimes(s, _now, alertDays: 5);
    expect(times.first, DateTime(2026, 11, 26, 10));
    expect(times.last, DateTime(2026, 12, 1, 10));
    expect(times.length, 6);
    final late = refillReminderTimes(s, DateTime(2026, 11, 27, 11), alertDays: 5);
    expect(late.first, DateTime(2026, 11, 28, 10)); // past 10 AM: from tomorrow
  });

  test('labels in both languages', () {
    expect(stockUnits(12, MedicineForm.tablet, 'en'), '12 tablets');
    expect(stockUnits(1, MedicineForm.capsule, 'en'), '1 capsule');
    expect(stockUnits(12, MedicineForm.tablet, 'bn'), '১২টি ট্যাবলেট');
    expect(stockUnits(100, MedicineForm.syrup, 'en'), '100 ml');
    expect(amountText(2.5, 'en'), '2.5');
    final s = stockStatus(_med(stock: 12), const [], _now)!;
    expect(daysLeftText(s, 'en'), '6 days left');
    expect(daysLeftText(s, 'bn'), 'আর ৬ দিন চলবে');
  });

  test('stock and the reminder setting are saved and read back', () {
    final m = Medicine.fromJson(_med().toJson());
    expect(m.stockCount, 20);
    expect(m.stockSetAt, _set);
    expect(m.copyWith(clearStock: true).stockCount, isNull);
    expect(AppSettings().refillAlertDays, 5);
    expect(AppSettings.fromJson(AppSettings(refillAlertDays: 7).toJson()).refillAlertDays, 7);
  });
}
