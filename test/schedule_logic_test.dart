import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/utils/schedule_utils.dart';
import 'package:osudsheba/core/utils/time_utils.dart';

Medicine _med({
  String id = 'm1',
  List<String> times = const ['08:00 AM'],
  DateTime? start,
  DateTime? end,
  DateTime? created,
  String status = 'active',
}) =>
    Medicine(
      id: id,
      name: 'Napa',
      strength: '500mg',
      form: MedicineForm.tablet,
      dose: '1',
      times: times,
      mealRelation: 'After Meal',
      instruction: '',
      startDate: start,
      endDate: end,
      createdAt: created,
      status: status,
    );

DoseLog _log(String medId, String slot, DateTime at, String status) => DoseLog(
      id: '$medId-$slot-$status-${at.toIso8601String()}',
      medicineId: medId,
      medicineName: 'Napa',
      scheduledTime: slot,
      actualTime: at,
      status: status,
    );

void main() {
  group('time parsing (alarms must understand every saved time)', () {
    test('12-hour formats', () {
      expect(normalizeTimeString('8:00 AM'), '08:00 AM');
      expect(normalizeTimeString('08:00am'), '08:00 AM');
      expect(normalizeTimeString('8 pm'), '08:00 PM');
      expect(normalizeTimeString('12:00 AM'), '12:00 AM');
      expect(normalizeTimeString('12:30 PM'), '12:30 PM');
    });

    test('24-hour formats from phones set to 24-hour time', () {
      expect(normalizeTimeString('20:30'), '08:30 PM');
      expect(normalizeTimeString('00:15'), '12:15 AM');
      expect(normalizeTimeString('13'), '01:00 PM');
      expect(normalizeTimeString('20.30'), '08:30 PM');
    });

    test('Bangla digits', () {
      expect(normalizeTimeString('৮:৩০ PM'), '08:30 PM');
    });

    test('rejects nonsense and ambiguous input', () {
      expect(normalizeTimeString('morning'), isNull);
      expect(normalizeTimeString('25:00'), isNull);
      expect(normalizeTimeString('8:75 AM'), isNull);
      expect(normalizeTimeString('8'), isNull); // AM or PM?
      expect(invalidTimes(['8:00 AM', 'after lunch']), ['after lunch']);
    });

    test('sameTimeOfDay ignores formatting', () {
      expect(sameTimeOfDay('8:00 AM', '08:00 AM'), isTrue);
      expect(sameTimeOfDay('20:00', '08:00 PM'), isTrue);
      expect(sameTimeOfDay('08:00 AM', '08:00 PM'), isFalse);
    });

    test('normalizeTimeList sorts and removes duplicates', () {
      expect(normalizeTimeList(['8:00 PM', '08:00 AM', '20:00', '2 pm']),
          ['08:00 AM', '02:00 PM', '08:00 PM']);
    });
  });

  group('course dates', () {
    final today = DateTime(2026, 11, 18, 9);
    test('ongoing medicine is scheduled', () {
      expect(_med().isScheduledOn(today), isTrue);
    });
    test('ended course is not scheduled', () {
      expect(_med(end: DateTime(2026, 11, 17)).isScheduledOn(today), isFalse);
      expect(_med(end: DateTime(2026, 11, 18)).isScheduledOn(today), isTrue); // last day counts
    });
    test('future start is not scheduled yet', () {
      expect(_med(start: DateTime(2026, 11, 19)).isScheduledOn(today), isFalse);
    });
    test('paused medicine is not scheduled', () {
      expect(_med(status: 'paused').isScheduledOn(today), isFalse);
    });
  });

  group('missed-dose detection', () {
    final created = DateTime(2026, 11, 10);

    test('overdue dose with no log is missed after the grace period', () {
      final now = DateTime(2026, 11, 18, 9, 30);
      final missed = findMissedDoses(
        medicines: [_med(created: created)],
        logs: const [],
        now: now,
        lookbackDays: 1,
      );
      expect(missed.length, 1);
      expect(missed.first.slot, '08:00 AM');
    });

    test('not missed within the grace period', () {
      final now = DateTime(2026, 11, 18, 8, 30);
      expect(
        findMissedDoses(medicines: [_med(created: created)], logs: const [], now: now, lookbackDays: 1),
        isEmpty,
      );
    });

    test('taken or skipped doses are not missed', () {
      final now = DateTime(2026, 11, 18, 12);
      for (final status in ['taken', 'skipped', 'missed']) {
        final logs = [_log('m1', '8:00 AM', DateTime(2026, 11, 18, 8, 5), status)];
        expect(
          findMissedDoses(medicines: [_med(created: created)], logs: logs, now: now, lookbackDays: 1),
          isEmpty,
          reason: status,
        );
      }
    });

    test('a snoozed-then-ignored dose IS missed', () {
      final now = DateTime(2026, 11, 18, 12);
      final logs = [_log('m1', '08:00 AM', DateTime(2026, 11, 18, 8, 1), 'snoozed')];
      expect(
        findMissedDoses(medicines: [_med(created: created)], logs: logs, now: now, lookbackDays: 1).length,
        1,
      );
    });

    test('doses before the medicine was added are never missed', () {
      final now = DateTime(2026, 11, 18, 15);
      final addedToday = DateTime(2026, 11, 18, 14);
      expect(
        findMissedDoses(medicines: [_med(created: addedToday)], logs: const [], now: now),
        isEmpty,
      );
    });

    test('doses after the course ended are never missed', () {
      final now = DateTime(2026, 11, 18, 15);
      expect(
        findMissedDoses(
          medicines: [_med(created: created, end: DateTime(2026, 11, 16))],
          logs: const [],
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('today status', () {
    final now = DateTime(2026, 11, 18, 13);
    final med = _med(times: const ['08:00 AM', '08:00 PM']);

    test('one of two doses taken is not "Taken"', () {
      final logs = [_log('m1', '08:00 AM', DateTime(2026, 11, 18, 8, 2), 'taken')];
      expect(todayStatusFor(med, logs, now), 'Pending');
    });

    test('all doses taken is "Taken"', () {
      final logs = [
        _log('m1', '08:00 AM', DateTime(2026, 11, 18, 8, 2), 'taken'),
        _log('m1', '08:00 PM', DateTime(2026, 11, 18, 12, 0), 'taken'),
      ];
      expect(todayStatusFor(med, logs, now), 'Taken');
    });

    test('a missed dose shows "Missed"', () {
      final logs = [_log('m1', '08:00 AM', DateTime(2026, 11, 18, 8), 'missed')];
      expect(todayStatusFor(med, logs, now), 'Missed');
    });
  });
}
