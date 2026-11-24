// The Home tab should fit on one screen on normal phones (no scrolling) with a typical day:
// three medicines, morning doses taken, one afternoon dose not recorded yet.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osudsheba/app/theme.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/providers/clock_provider.dart';
import 'package:osudsheba/core/services/local_storage_service.dart';
import 'package:osudsheba/core/services/mock_data_service.dart';
import 'package:osudsheba/features/home/presentation/home_screen.dart';
import 'package:osudsheba/features/home/presentation/main_navigation_screen.dart';
import 'package:osudsheba/features/medicines/presentation/medicine_detail_screen.dart';

class _Phone {
  const _Phone(this.name, this.width, this.height, this.dpr, this.top, this.bottom);
  final String name;
  final double width, height, dpr, top, bottom;
}

const _phones = [
  _Phone('Galaxy S23 Ultra', 384, 823.5, 2.8125, 32, 48),
  _Phone('typical 6.5" budget phone', 360, 800, 3.0, 28, 48),
];

final _now = DateTime(2026, 11, 19, 15, 0); // 3 PM
final _yesterday = DateTime(2026, 11, 18);

List<Medicine> _medicines(bool bn) {
  Medicine med(String id, String name, String strength, MedicineForm form, String dose, List<String> times,
          String meal) =>
      Medicine(
        id: id,
        name: name,
        strength: strength,
        form: form,
        dose: dose,
        times: times,
        mealRelation: meal,
        instruction: id == 'm1' ? (bn ? 'এক গ্লাস পানির সাথে খাবেন' : 'Take with a full glass of water') : '',
        startDate: _yesterday,
        createdAt: _yesterday,
      );
  return [
    med('m1', bn ? 'নাপা এক্সটেন্ড' : 'Napa Extend', '665mg', MedicineForm.tablet, '1 Tablet',
        ['08:00 AM', '02:00 PM', '09:00 PM'], 'After Meal'),
    med('m2', bn ? 'সেকলো' : 'Seclo', '20mg', MedicineForm.capsule, '1 Capsule', ['08:00 AM', '08:00 PM'],
        'Before Meal'),
    med('m3', bn ? 'অ্যামলোডিপিন' : 'Amlodipine', '5mg', MedicineForm.tablet, '1 Tablet', ['08:00 AM'],
        'With Meal'),
  ];
}

List<DoseLog> _logs() => [
      for (final id in ['m1', 'm2', 'm3'])
        DoseLog(
          id: 'l$id',
          medicineId: id,
          medicineName: id,
          scheduledTime: '08:00 AM',
          actualTime: DateTime(2026, 11, 19, 8, 10),
          status: 'taken',
        ),
    ];

Future<double> _homeScrollExtent(WidgetTester tester, _Phone phone, String lang, double textScale,
    {bool detail = false, Future<void> Function()? before}) async {
  tester.view.devicePixelRatio = phone.dpr;
  tester.view.physicalSize = Size(phone.width * phone.dpr, phone.height * phone.dpr);
  tester.view.padding = FakeViewPadding(top: phone.top * phone.dpr, bottom: phone.bottom * phone.dpr);
  addTearDown(tester.view.reset);

  final storage = LocalStorageService();
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => detail
          ? MedicineDetailScreen(medicine: _medicines(lang == 'bn').first)
          : const MainNavigationScreen(initialTab: 0),
    ),
    GoRoute(path: '/:rest(.*)', builder: (_, _) => const Scaffold()),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userUidProvider.overrideWithValue(null),
      appSettingsProvider.overrideWith((ref) => AppSettingsNotifier(storage, AppSettings(languageCode: lang))),
      medicinesProvider.overrideWith((ref) => MedicinesNotifier(storage, _medicines(lang == 'bn'), null)),
      doseLogsProvider.overrideWith((ref) => DoseLogsNotifier(storage, _logs(), null)),
      minuteClockProvider.overrideWith((ref) => Stream.value(_now)),
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme.copyWith(
        textTheme: AppTheme.lightTheme.textTheme.apply(fontFamily: 'Roboto'),
        primaryTextTheme: AppTheme.lightTheme.primaryTextTheme.apply(fontFamily: 'Roboto'),
      ),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  // Sanity: the fixed clock was used. At 3 PM the 2 PM dose is not recorded yet, so the
  // card shows it, an hour late.
  if (!detail) {
    expect(find.text(lang == 'bn' ? 'দুপুর ২:০০' : '2:00 PM'), findsOneWidget);
    expect(find.text(lang == 'bn' ? '১ ঘণ্টা দেরি' : '1 h late'), findsOneWidget);
  }
  if (before != null) await before();
  final scrollable = tester.state<ScrollableState>(
    find.descendant(
            of: find.byType(detail ? MedicineDetailScreen : HomeScreen), matching: find.byType(Scrollable))
        .first,
  );
  final extent = scrollable.position.maxScrollExtent;
  await tester.pumpWidget(const SizedBox());
  return extent;
}

/// Real letter widths (Roboto from the Flutter SDK) instead of the square test font.
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');
  final loader = FontLoader('Roboto');
  for (final w in ['regular', 'medium', 'bold']) {
    final f = File('${dir.path}/roboto-$w.ttf');
    if (f.existsSync()) loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadRoboto);

  setUp(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in ['flutter_tts', 'dexterous.com/flutter/local_notifications']) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => 1);
    }
  });

  for (final phone in _phones) {
    for (final lang in ['en', 'bn']) {
      testWidgets('Home fits without scrolling on ${phone.name} ($lang, default text size)', (tester) async {
        final extent = await _homeScrollExtent(tester, phone, lang, 1.1);
        expect(extent, 0.0, reason: 'Home needs ${extent.toStringAsFixed(0)}px of scrolling');
      });
    }
  }

  for (final phone in _phones) {
    for (final lang in ['en', 'bn']) {
      testWidgets('Medicine Details fits without scrolling on ${phone.name} ($lang, 3 times a day)', (tester) async {
        final extent = await _homeScrollExtent(tester, phone, lang, 1.1, detail: true);
        expect(extent, 0.0, reason: 'Medicine Details needs ${extent.toStringAsFixed(0)}px of scrolling');
      });
    }
  }

  for (final lang in ['en', 'bn']) {
    testWidgets('a dose already taken shows "Taken at" with Undo, not a second Mark button ($lang)', (tester) async {
      final extent = await _homeScrollExtent(tester, _phones.last, lang, 1.1, detail: true, before: () async {
        await tester.tap(find.widgetWithText(ChoiceChip, '08:00 AM'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining(lang == 'bn' ? 'খাওয়া হয়েছে' : 'Taken at 08:10 AM'), findsWidgets);
        expect(find.text(lang == 'bn' ? 'ফিরিয়ে নিন' : 'Undo'), findsOneWidget);
        expect(find.textContaining(lang == 'bn' ? 'এর ডোজ খেয়েছি' : 'as taken'), findsNothing);
      });
      expect(extent, 0.0);
    });
  }

  testWidgets('Medicine Details still scrolls when it cannot fit (largest text)', (tester) async {
    final extent = await _homeScrollExtent(tester, _phones.last, 'bn', 2.0, detail: true);
    expect(extent, greaterThan(0.0));
  });

  testWidgets('Home still scrolls when it cannot fit (largest text)', (tester) async {
    final extent = await _homeScrollExtent(tester, _phones.last, 'bn', 2.0);
    expect(extent, greaterThan(0.0));
  });
}
