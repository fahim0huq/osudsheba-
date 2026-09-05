import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:osudsheba/app/app.dart';
import 'package:osudsheba/core/services/notification_service.dart';

void main() {
  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync('hive_test');
    Hive.init(tempDir.path);
    await Hive.openBox<Map>('app_settings');
    await Hive.openBox<Map>('medicines');
    await Hive.openBox<Map>('dose_logs');
    await Hive.openBox<Map>('caregiver_alerts');
    await Hive.openBox<Map>('user_profile');
  });

  testWidgets('App renders OsudShebaApp smoke test', (WidgetTester tester) async {
    // Build our app inside ProviderScope and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: OsudShebaApp(),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify that the main OsudShebaApp is rendered.
    expect(find.byType(OsudShebaApp), findsOneWidget);

    // Clean up
    NotificationService.instance.stopForegroundAlarmMonitoring();
    await tester.pumpWidget(const SizedBox());
  });
}
