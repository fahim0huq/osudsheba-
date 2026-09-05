import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'router.dart';
import 'theme.dart';
import '../core/services/notification_service.dart';
import '../core/services/mock_data_service.dart';
import '../core/models/mock_models.dart';

class OsudShebaApp extends ConsumerStatefulWidget {
  const OsudShebaApp({super.key});

  @override
  ConsumerState<OsudShebaApp> createState() => _OsudShebaAppState();
}

class _OsudShebaAppState extends ConsumerState<OsudShebaApp> {
  StreamSubscription<String?>? _notificationSubscription;
  static const MethodChannel _alarmChannel = MethodChannel('com.medisathi.bd.osudsheba/alarm');

  String? _lastRoutedPayload;
  DateTime? _lastRoutedTime;

  @override
  void initState() {
    super.initState();
    _notificationSubscription = NotificationService.selectNotificationPayload.stream.listen((String? payload) {
      _handlePayloadNavigation(payload);
    });

    // Listen to incoming alarm intents directly from MainActivity (onNewIntent)
    _alarmChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmReceived') {
        final payload = call.arguments as String?;
        dev.log('App: Alarm received via MethodChannel: $payload');
        _handlePayloadNavigation(payload);
      }
    });

    // Handle cold start launch payload if app was opened directly from alarm/notification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialPayload = NotificationService.instance.launchPayload;
      if (initialPayload != null) {
        _handlePayloadNavigation(initialPayload);
        NotificationService.instance.launchPayload = null;
      }
    });
  }

  void _handlePayloadNavigation(String? payload) {
    if (payload == null) return;
    
    // Deduplicate rapid duplicate triggers (e.g. within 2 seconds with identical payload)
    final now = DateTime.now();
    if (_lastRoutedPayload == payload && _lastRoutedTime != null && now.difference(_lastRoutedTime!) < const Duration(seconds: 2)) {
      dev.log('Notification payload navigation debounced: $payload');
      return;
    }
    _lastRoutedPayload = payload;
    _lastRoutedTime = now;

    try {
      final data = jsonDecode(payload);
      final String medicineId = data['medicineId'] ?? '';
      final String scheduledTime = data['scheduledTime'] ?? '';
      appRouter.push('/reminder-alert?medicineId=$medicineId&scheduledTime=${Uri.encodeComponent(scheduledTime)}');
    } catch (e) {
      dev.log('Notification tap routing error: $e');
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    NotificationService.instance.stopForegroundAlarmMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medicines = ref.watch(medicinesProvider);
    NotificationService.instance.startForegroundAlarmMonitoring(medicines);

    ref.listen<List<Medicine>>(medicinesProvider, (previous, next) {
      NotificationService.instance.rescheduleAll(next);
      NotificationService.instance.startForegroundAlarmMonitoring(next);
    });

    return MaterialApp.router(
      title: 'OsudSheba',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
