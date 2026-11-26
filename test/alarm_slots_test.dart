// The full-screen alarm for a meal-time slot: names the slot, one page per medicine, and
// the arrows (as well as swiping) step through them. Also: it marks itself open, which
// keeps the start-up screen from navigating over it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/services/local_storage_service.dart';
import 'package:osudsheba/core/services/mock_data_service.dart';
import 'package:osudsheba/core/services/notification_service.dart';
import 'package:osudsheba/features/reminders/presentation/reminder_alert_screen.dart';

Medicine med(String id, String name) => Medicine(
      id: id,
      name: name,
      strength: '500mg',
      form: MedicineForm.tablet,
      dose: '1 Tablet',
      times: const ['08:30 AM'],
      mealRelation: 'After Meal',
      instruction: '',
      slots: const ['morning_after'],
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final c in ['flutter_tts', 'dexterous.com/flutter/local_notifications', 'com.medisathi.bd.osudsheba/alarm']) {
      messenger.setMockMethodCallHandler(MethodChannel(c), (_) async => 1);
    }
  });

  testWidgets('slot alarm: names the slot, and the arrows go through the medicines', (tester) async {
    tester.view.physicalSize = const Size(1080, 2316);
    tester.view.devicePixelRatio = 2.8125;
    addTearDown(tester.view.reset);
    final storage = LocalStorageService();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const ReminderAlertScreen(medicineId: 'a', scheduledTime: '08:30 AM')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userUidProvider.overrideWithValue(null),
        appSettingsProvider.overrideWith((ref) => AppSettingsNotifier(storage, AppSettings())),
        medicinesProvider.overrideWith(
            (ref) => MedicinesNotifier(storage, [med('a', 'Napa'), med('b', 'Seclo'), med('c', 'Amdocal')], null)),
        doseLogsProvider.overrideWith((ref) => DoseLogsNotifier(storage, [], null)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(NotificationService.instance.alarmScreenOpen.value, isTrue, reason: 'start-up must not navigate over it');
    expect(find.textContaining('Morning · after meal'), findsOneWidget);
    expect(find.textContaining('1 of 3'), findsOneWidget);

    final back = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_left_rounded));
    expect(back.onPressed, isNull, reason: 'no previous medicine on the first page');

    await tester.tap(find.byTooltip('Next medicine'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50)); // let the page animation run
    }
    expect(find.textContaining('2 of 3'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(NotificationService.instance.alarmScreenOpen.value, isFalse, reason: 'cleared once it closes');
  });
}
