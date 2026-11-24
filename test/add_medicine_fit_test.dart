// The Add Medicine form should fit on one screen on normal phones (no scrolling), and only
// scroll on small phones or at large text sizes.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osudsheba/app/theme.dart';
import 'package:osudsheba/core/models/mock_models.dart';
import 'package:osudsheba/core/services/local_storage_service.dart';
import 'package:osudsheba/core/services/mock_data_service.dart';
import 'package:osudsheba/features/caregiver/presentation/caregiver_dashboard_screen.dart';
import 'package:osudsheba/features/home/presentation/main_navigation_screen.dart';
import 'package:osudsheba/features/medicines/presentation/add_medicine_screen.dart';
import 'package:osudsheba/features/medicines/presentation/edit_medicine_screen.dart';

/// A phone: logical size, pixel ratio, status bar and system navigation bar heights.
class _Phone {
  const _Phone(this.name, this.width, this.height, this.dpr, this.top, this.bottom);
  final String name;
  final double width, height, dpr, top, bottom;
}

const _phones = [
  _Phone('Galaxy S23 Ultra', 384, 823.5, 2.8125, 32, 48),
  _Phone('typical 6.5" budget phone', 360, 800, 3.0, 28, 48),
];

/// The medicine being edited in the Edit Medicine checks (one end date, three times).
final _editTarget = Medicine(
  id: 'm1',
  name: 'Napa Extend',
  strength: '665mg',
  form: MedicineForm.drops,
  dose: '2 drops',
  times: const ['08:00 AM', '02:00 PM', '08:00 PM'],
  mealRelation: 'After Meal',
  instruction: '',
  endDate: DateTime.now().add(const Duration(days: 20)),
);

/// How far a medicine form scrolls: Add Medicine opened from the Add tab, or Edit Medicine.
Future<double> _scrollExtent(WidgetTester tester, _Phone phone, String lang, double textScale,
    {bool edit = false, bool custom = false, bool family = false}) async {
  tester.view.devicePixelRatio = phone.dpr;
  tester.view.physicalSize = Size(phone.width * phone.dpr, phone.height * phone.dpr);
  tester.view.padding = FakeViewPadding(top: phone.top * phone.dpr, bottom: phone.bottom * phone.dpr);
  addTearDown(tester.view.reset);

  final storage = LocalStorageService();
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => edit
          ? EditMedicineScreen(medicine: _editTarget)
          : MainNavigationScreen(initialTab: family ? 4 : 1),
    ),
    GoRoute(path: '/:rest(.*)', builder: (_, _) => const Scaffold()),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      userUidProvider.overrideWithValue(null),
      appSettingsProvider.overrideWith((ref) => AppSettingsNotifier(storage, AppSettings(languageCode: lang))),
      medicinesProvider.overrideWith((ref) => MedicinesNotifier(storage, [_editTarget], null)),
      doseLogsProvider.overrideWith((ref) => DoseLogsNotifier(storage, [], null)),
      // Worst case for the Family tab: a missed-dose alert banner is showing.
      caregiverAlertsProvider.overrideWith((ref) => CaregiverAlertsNotifier(storage, [
            CaregiverAlert(id: 'a1', title: 'Missed dose', message: 'Napa Extend 665mg (8:00 AM) was not taken.', severity: 'High', time: '9:00 AM'),
          ], null)),
    ],
    child: MaterialApp.router(
      // Real letter widths (see _loadRoboto), not the square test font.
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
  if (custom) {
    // "3 times", then "Custom" (it opens the time picker: cancel it), as a user would.
    final add = find.byType(AddMedicineScreen);
    await tester.tap(find.descendant(of: add, matching: find.text('3 times')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.descendant(of: add, matching: find.text('Custom')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.text('Cancel'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.descendant(of: add, matching: find.textContaining(RegExp(r'^\d{1,2}:\d{2} [AP]M$'))), findsNWidgets(3));
  }
  final scrollable = tester.state<ScrollableState>(
    find.descendant(of: find.byType(family ? CaregiverDashboardScreen : (edit ? EditMedicineScreen : AddMedicineScreen)), matching: find.byType(Scrollable)).first,
  );
  final extent = scrollable.position.maxScrollExtent;
  await tester.pumpWidget(const SizedBox());
  return extent;
}

/// Widget tests draw text with a font where every letter is a full square, which makes
/// text far wider than on a phone. Load Roboto from the Flutter SDK instead (close to the
/// app's Noto Sans, which is a few percent wider: the on-device check covers that).
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (_) async => 1,
    );
  });

  for (final phone in _phones) {
    testWidgets('Add Medicine fits without scrolling on ${phone.name} (default text size)', (tester) async {
      final extent = await _scrollExtent(tester, phone, 'en', 1.1);
      expect(extent, 0.0, reason: 'form needs ${extent.toStringAsFixed(0)}px of scrolling');
    });
  }

  testWidgets('Add Medicine fits on ${_phones.first.name} with 3 times, then Custom', (tester) async {
    final extent = await _scrollExtent(tester, _phones.first, 'en', 1.1, custom: true);
    expect(extent, 0.0, reason: 'form needs ${extent.toStringAsFixed(0)}px of scrolling');
  });

  for (final phone in _phones) {
    testWidgets('Edit Medicine fits without scrolling on ${phone.name} (3 times, end date set)', (tester) async {
      final extent = await _scrollExtent(tester, phone, 'en', 1.1, edit: true);
      expect(extent, 0.0, reason: 'form needs ${extent.toStringAsFixed(0)}px of scrolling');
    });
  }

  for (final phone in _phones) {
    testWidgets('Family tab fits without scrolling on ${phone.name} (with a missed-dose alert)', (tester) async {
      final extent = await _scrollExtent(tester, phone, 'en', 1.1, family: true);
      expect(extent, 0.0, reason: 'screen needs ${extent.toStringAsFixed(0)}px of scrolling');
    });
  }

  testWidgets('Add Medicine still scrolls when it cannot fit (largest text)', (tester) async {
    final extent = await _scrollExtent(tester, _phones.last, 'en', 2.0);
    expect(extent, greaterThan(0.0));
  });
}
