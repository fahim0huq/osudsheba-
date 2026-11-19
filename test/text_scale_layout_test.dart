// Layout check at the largest text size the app allows (2.0) in Bangla, on a small phone.
// Any RenderFlex overflow or other layout error is collected and reported per screen.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osudsheba/app/theme.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/services/local_storage_service.dart';
import 'package:osudsheba/core/services/mock_data_service.dart';
import 'package:osudsheba/features/home/presentation/home_screen.dart';
import 'package:osudsheba/features/home/presentation/main_navigation_screen.dart';
import 'package:osudsheba/features/medicines/presentation/add_medicine_screen.dart';
import 'package:osudsheba/features/medicines/presentation/edit_medicine_screen.dart';
import 'package:osudsheba/features/reminders/presentation/reminder_alert_screen.dart';

const _phoneSizes = <Size>[Size(360, 640), Size(320, 568)];

List<Medicine> _medicines() {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  Medicine med(String id, String name, String strength, MedicineForm form, List<String> times,
          String meal, String instruction) =>
      Medicine(
        id: id,
        name: name,
        strength: strength,
        form: form,
        dose: '১টি ট্যাবলেট',
        times: times,
        mealRelation: meal,
        instruction: instruction,
        startDate: yesterday,
        createdAt: yesterday,
      );
  // Long Bangla names and instructions on purpose: worst case for wrapping.
  return [
    med('m1', 'নাপা এক্সটেন্ড প্যারাসিটামল', '৬৬৫ মিলিগ্রাম', MedicineForm.tablet,
        ['06:00 AM', '08:00 AM', '02:00 PM', '09:00 PM'], 'After Meal',
        'খাবারের পরে এক গ্লাস হালকা গরম পানির সাথে খাবেন'),
    med('m2', 'সেকলো (ওমিপ্রাজল) ক্যাপসুল', '২০ মিলিগ্রাম', MedicineForm.capsule,
        ['08:00 AM', '08:00 PM', '11:30 PM'], 'Before Meal', 'খাবারের ৩০ মিনিট আগে'),
    med('m3', 'অ্যামলোডিপিন ও লোসার্টান পটাশিয়াম', '৫/৫০ মিলিগ্রাম', MedicineForm.tablet,
        ['08:00 AM', '11:30 PM'], 'With Meal', ''),
  ];
}

Widget _harness(Widget screen) {
  final storage = LocalStorageService();
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => screen),
    GoRoute(path: '/:rest(.*)', builder: (_, _) => const Scaffold()),
  ]);
  return ProviderScope(
    overrides: [
      userUidProvider.overrideWithValue(null),
      appSettingsProvider.overrideWith(
        (ref) => AppSettingsNotifier(
          storage,
          AppSettings(languageCode: 'bn', userRole: 'Patient', onboardingCompleted: true),
        ),
      ),
      medicinesProvider.overrideWith((ref) => MedicinesNotifier(storage, _medicines(), null)),
      doseLogsProvider.overrideWith((ref) => DoseLogsNotifier(storage, [], null)),
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
        child: child!,
      ),
    ),
  );
}

Future<void> _expectNoLayoutErrors(WidgetTester tester, String name, Widget screen,
    {void Function(Size screenSize)? alsoCheck}) async {
  for (final size in _phoneSizes) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) =>
        errors.add('${details.exceptionAsString().split('\n').first}  @ ${_creator(details)}');
    try {
      await tester.pumpWidget(_harness(screen));
      // Let entrance animations finish (the alarm pulse repeats, so no pumpAndSettle).
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      alsoCheck?.call(size);
    } finally {
      FlutterError.onError = previous;
      await tester.pumpWidget(const SizedBox());
    }
    expect(errors, isEmpty, reason: '$name at ${size.width.toInt()}x${size.height.toInt()}:\n'
        '${errors.join('\n')}');
  }
}

/// The overflow message plus the source line of the widget that overflowed.
String _creator(FlutterErrorDetails d) {
  final m = RegExp(r'/(lib/[^\s:]+\.dart:\d+)').firstMatch(d.toString());
  return m?.group(1) ?? '(framework widget)';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Text-to-speech and notification plugins are not available in widget tests.
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in ['flutter_tts', 'dexterous.com/flutter/local_notifications']) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
    }
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  testWidgets('Home (with bottom navigation) fits at text scale 2.0 in Bangla', (tester) async {
    await _expectNoLayoutErrors(
      tester,
      'Home',
      const MainNavigationScreen(),
      // Regression: the bottom bar once filled the whole screen and left Home 0px high.
      alsoCheck: (screen) {
        final home = tester.getSize(find.byType(HomeScreen));
        expect(home.height, greaterThan(screen.height / 2), reason: 'Home page is squeezed by the bottom bar');
      },
    );
  });

  testWidgets('Family tab fits at text scale 2.0 in Bangla', (tester) async {
    await _expectNoLayoutErrors(tester, 'Family', const MainNavigationScreen(initialTab: 4));
  });

  testWidgets('Alarm screen fits at text scale 2.0 in Bangla', (tester) async {
    await _expectNoLayoutErrors(
      tester,
      'Alarm',
      const ReminderAlertScreen(medicineId: 'm1', scheduledTime: '08:00 AM'),
      // The action buttons must be fully on screen without scrolling.
      alsoCheck: (screen) {
        for (final icon in [Icons.check_circle_rounded, Icons.snooze_rounded]) {
          final rect = tester.getRect(find.byIcon(icon).last);
          expect(rect.bottom, lessThanOrEqualTo(screen.height), reason: '$icon is below the screen');
        }
        final takenButton = tester.getRect(find.byType(ElevatedButton));
        expect(takenButton.bottom, lessThanOrEqualTo(screen.height));
      },
    );
  });

  testWidgets('Add Medicine fits at text scale 2.0 in Bangla', (tester) async {
    await _expectNoLayoutErrors(tester, 'Add Medicine', const AddMedicineScreen());
  });

  testWidgets('Edit Medicine fits at text scale 2.0 in Bangla', (tester) async {
    await _expectNoLayoutErrors(tester, 'Edit Medicine', EditMedicineScreen(medicine: _medicines().first));
  });
}
