// The Home screen's "Next dose" card, "not recorded yet" list and progress counts.
import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/utils/home_schedule.dart';

final _yesterday = DateTime(2026, 11, 18);

Medicine _med(String id, List<String> times, {DateTime? end, String status = 'active'}) => Medicine(
      id: id,
      name: 'Med $id',
      strength: '',
      form: MedicineForm.tablet,
      dose: '1',
      times: times,
      mealRelation: 'After Meal',
      instruction: '',
      startDate: _yesterday,
      endDate: end,
      status: status,
    );

DoseLog _log(String medId, String slot, DateTime at, String status) => DoseLog(
      id: '$medId-$slot-$status',
      medicineId: medId,
      medicineName: 'Med $medId',
      scheduledTime: slot,
      actualTime: at,
      status: status,
    );

DateTime _at(int h, int m) => DateTime(2026, 11, 19, h, m);

void main() {
  final a = _med('a', ['08:00 AM', '02:00 PM', '09:00 PM']);
  final b = _med('b', ['08:00 AM', '09:00 PM']);

  group('findNextDose', () {
    test('picks the earliest later slot and groups every medicine due then', () {
      final next = findNextDose(medicines: [a, b], logs: const [], now: _at(7, 0))!;
      expect(next.time, '08:00 AM');
      expect(next.medicines.map((m) => m.id), ['a', 'b']);
      expect(next.isTomorrow, isFalse);
      expect(next.scheduledAt, _at(8, 0));
    });

    test('moves on once the time passes, without any new log (the stale-card bug)', () {
      final before = findNextDose(medicines: [a, b], logs: const [], now: _at(7, 59))!;
      final after = findNextDose(medicines: [a, b], logs: const [], now: _at(8, 1))!;
      expect(before.time, '08:00 AM');
      expect(after.time, '02:00 PM');
      expect(after.medicines.map((m) => m.id), ['a']);
    });

    test('a dose taken early is no longer next', () {
      final logs = [_log('a', '02:00 PM', _at(13, 30), 'taken')];
      final next = findNextDose(medicines: [a, b], logs: logs, now: _at(13, 40))!;
      expect(next.time, '09:00 PM');
    });

    test('only the medicines not yet taken stay in a shared slot', () {
      final logs = [_log('a', '09:00 PM', _at(20, 50), 'taken')];
      final next = findNextDose(medicines: [a, b], logs: logs, now: _at(20, 55))!;
      expect(next.time, '09:00 PM');
      expect(next.medicines.map((m) => m.id), ['b']);
    });

    test('skipped and missed doses also count as dealt with', () {
      final logs = [
        _log('a', '09:00 PM', _at(20, 50), 'skipped'),
        _log('b', '09:00 PM', _at(20, 51), 'missed'),
      ];
      final next = findNextDose(medicines: [a, b], logs: logs, now: _at(20, 55))!;
      expect(next.isTomorrow, isTrue);
    });

    test('after the last dose of the day it shows tomorrow, not the dose just taken', () {
      final logs = [
        _log('a', '09:00 PM', _at(20, 58), 'taken'),
        _log('b', '09:00 PM', _at(20, 58), 'taken'),
      ];
      final next = findNextDose(medicines: [a, b], logs: logs, now: _at(20, 59))!;
      expect(next.isTomorrow, isTrue);
      expect(next.time, '08:00 AM');
      expect(next.scheduledAt, DateTime(2026, 11, 20, 8, 0));
    });

    test("yesterday's logs do not hide today's doses", () {
      final logs = [_log('a', '02:00 PM', DateTime(2026, 11, 18, 14, 0), 'taken')];
      final next = findNextDose(medicines: [a], logs: logs, now: _at(13, 0))!;
      expect(next.time, '02:00 PM');
    });

    test('matches times written differently ("8:00 PM" vs "08:00 PM")', () {
      final c = _med('c', ['8:00 PM']);
      final logs = [_log('c', '08:00 PM', _at(19, 50), 'taken')];
      final next = findNextDose(medicines: [c], logs: logs, now: _at(19, 55))!;
      expect(next.isTomorrow, isTrue);
    });

    test('tomorrow skips a medicine that ends today', () {
      final ending = _med('e', ['07:00 AM'], end: _at(0, 0));
      final next = findNextDose(medicines: [ending, b], logs: const [], now: _at(22, 0))!;
      expect(next.isTomorrow, isTrue);
      expect(next.medicines.map((m) => m.id), ['b']);
    });

    test('paused medicines and an empty list give no next dose', () {
      expect(findNextDose(medicines: [_med('p', ['09:00 AM'], status: 'paused')], logs: const [], now: _at(8, 0)),
          isNull);
      expect(findNextDose(medicines: const [], logs: const [], now: _at(8, 0)), isNull);
    });
  });

  group('findOverdueToday', () {
    test('lists passed slots that were not taken or skipped, missed ones included', () {
      final logs = [
        _log('a', '08:00 AM', _at(8, 5), 'taken'),
        _log('b', '08:00 AM', _at(9, 0), 'missed'),
      ];
      final overdue = findOverdueToday(medicines: [a, b], logs: logs, now: _at(15, 0));
      expect(overdue.map((s) => s.time), ['08:00 AM', '02:00 PM']);
      expect(overdue.first.medicines.map((m) => m.id), ['b']);
    });

    test('a slot leaves the list once it is recorded', () {
      final logs = [_log('a', '08:00 AM', _at(10, 0), 'late')];
      expect(findOverdueToday(medicines: [a], logs: logs, now: _at(10, 1)), isEmpty);
    });
  });

  test('todayDoseCounts counts taken and late doses for today only', () {
    final logs = [
      _log('a', '08:00 AM', _at(8, 5), 'taken'),
      _log('b', '08:00 AM', _at(9, 30), 'late'),
      _log('a', '02:00 PM', _at(14, 0), 'skipped'),
      _log('a', '09:00 PM', DateTime(2026, 11, 18, 21, 0), 'taken'),
    ];
    final counts = todayDoseCounts(medicines: [a, b], logs: logs, now: _at(15, 0));
    expect(counts.taken, 2);
    expect(counts.total, 5);
  });
}
