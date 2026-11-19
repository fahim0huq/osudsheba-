// Family sharing: the caregiver's view of someone's day, and invite codes.
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osudsheba/core/providers/family_providers.dart';
import 'package:osudsheba/features/family/presentation/family_sections.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/services/family_service.dart';
import 'package:osudsheba/core/utils/care_view.dart';

Medicine med(String id, List<String> times, {DateTime? createdAt, String status = 'active'}) => Medicine(
      id: id,
      name: 'Med $id',
      strength: '5mg',
      form: MedicineForm.tablet,
      dose: '1 Tablet',
      times: times,
      mealRelation: 'None',
      instruction: '',
      status: status,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
    );

DoseLog log(String medId, String slot, String status, DateTime at) => DoseLog(
      id: '$medId-$slot-$status',
      medicineId: medId,
      medicineName: 'Med $medId',
      scheduledTime: slot,
      status: status,
      actualTime: at,
      scheduledDate: dateKey(at),
    );

void main() {
  group("caregiver's view of today", () {
    final now = DateTime(2026, 11, 18, 14, 10); // 2:10 PM

    test('taken, missed (over an hour late), due now and later', () {
      final doses = dosesForDay(
        medicines: [med('a', ['08:00 AM', '02:00 PM', '09:00 PM']), med('b', ['12:30 PM'])],
        logs: [log('a', '08:00 AM', 'taken', DateTime(2026, 11, 18, 8, 5))],
        now: now,
      );
      expect([for (final d in doses) '${d.medicine.id} ${d.slot} ${d.state.name}'], [
        'a 08:00 AM taken',
        'b 12:30 PM missed', // 1h40 late, nothing recorded
        'a 02:00 PM dueNow',
        'a 09:00 PM upcoming',
      ]);
    });

    test('a dose becomes "due now" 30 minutes early', () {
      final doses = dosesForDay(medicines: [med('a', ['02:40 PM'])], logs: [], now: now);
      expect(doses.single.state, DoseState.dueNow);
    });

    test('only snoozed still counts as due, skipped is shown as skipped', () {
      final doses = dosesForDay(
        medicines: [med('a', ['02:00 PM']), med('b', ['01:45 PM'])],
        logs: [
          log('a', '02:00 PM', 'snoozed', DateTime(2026, 11, 18, 14, 0)),
          log('b', '01:45 PM', 'skipped', DateTime(2026, 11, 18, 13, 50)),
        ],
        now: now,
      );
      expect(doses.map((d) => d.state), [DoseState.skipped, DoseState.dueNow]);
    });

    test('doses before the medicine was added, and paused medicines, are left out', () {
      final doses = dosesForDay(
        medicines: [
          med('new', ['08:00 AM', '09:00 PM'], createdAt: DateTime(2026, 11, 18, 13, 0)),
          med('paused', ['09:00 PM'], status: 'paused'),
        ],
        logs: [],
        now: now,
      );
      expect(doses.map((d) => '${d.medicine.id} ${d.slot}'), ['new 09:00 PM']);
    });

    test('7-day taken percentage per day; empty days are null', () {
      final values = dailyAdherence(
        logs: [
          log('a', '08:00 AM', 'taken', DateTime(2026, 11, 18, 8)),
          log('a', '09:00 PM', 'missed', DateTime(2026, 11, 17, 21)),
          log('a', '08:00 AM', 'taken', DateTime(2026, 11, 17, 8)),
          log('a', '08:00 AM', 'snoozed', DateTime(2026, 11, 16, 8)),
        ],
        now: now,
      );
      expect(values, [null, null, null, null, null, 50, 100]);
    });
  });

  group('invite codes', () {
    test('8 characters, never the easily confused 0, O, 1 or I', () {
      final r = Random(42);
      for (var i = 0; i < 500; i++) {
        final code = newInviteCode(r);
        expect(code.length, kInviteLength);
        expect(code, isNot(matches(RegExp('[0O1I]'))));
        expect(code.split('').every(kInviteAlphabet.contains), isTrue);
      }
    });

    test('typed codes are tidied: lower case, spaces and dashes are fine', () {
      expect(normalizeInviteCode('abcd-2345'), 'ABCD2345');
      expect(normalizeInviteCode(' AB CD 23 45 '), 'ABCD2345');
    });
  });

  testWidgets('Family sections still show when the cloud refuses (no red error screen)', (tester) async {
    Stream<T> refused<T>() => Stream<T>.error(Exception('permission-denied'));
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: SingleChildScrollView(child: FamilySections()))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        caringProvider.overrideWith((ref) => refused()),
        myFamilyProvider.overrideWith((ref) => refused()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('People I look after'), findsOneWidget);
    expect(find.text('My family'), findsOneWidget);
  });
}
