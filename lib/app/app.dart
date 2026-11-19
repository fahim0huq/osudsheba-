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
import '../core/utils/time_utils.dart';
import '../core/services/local_storage_service.dart';
import '../core/providers/cloud_sync_provider.dart';
import '../core/providers/family_providers.dart';

class OsudShebaApp extends ConsumerStatefulWidget {
  const OsudShebaApp({super.key});

  @override
  ConsumerState<OsudShebaApp> createState() => _OsudShebaAppState();
}

class _OsudShebaAppState extends ConsumerState<OsudShebaApp> with WidgetsBindingObserver {
  StreamSubscription<String?>? _notificationSubscription;
  static const MethodChannel _alarmChannel = MethodChannel('com.medisathi.bd.osudsheba/alarm');

  String? _lastRoutedPayload;
  DateTime? _lastRoutedTime;

  Timer? _missedDoseTimer;
  DateTime? _lastCloudSync;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cloud backup: every change saved on the phone is also sent to the user's account
    // (when the backup is on), and a full sync runs once each user's data has loaded.
    LocalStorageService().changeListener = ref.read(cloudSyncProvider);
    ref.listenManual<String?>(userUidProvider, (previous, uid) {
      if (uid != null) {
        _lastCloudSync = DateTime.now();
        runCloudSync(ref);
        // Family reminders arrive as push notifications on this phone.
        final family = ref.read(familyServiceProvider);
        if (family != null) registerForPush(family, uid);
      }
    }, fireImmediately: true);
    // Check for overdue doses every few minutes while the app is running.
    _missedDoseTimer = Timer.periodic(const Duration(minutes: 5), (_) => _reconcileDoses());
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
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final String medicineId = data['medicineId'] as String? ?? '';
      final String scheduledTime = data['scheduledTime'] as String? ?? '';
      final bool isTest = data['isTest'] == true;
      appRouter.push(
        '/reminder-alert?medicineId=$medicineId'
        '&scheduledTime=${Uri.encodeComponent(normalizeTimeString(scheduledTime) ?? scheduledTime)}'
        '${isTest ? '&test=1' : ''}',
      );
    } catch (e) {
      dev.log('Notification tap routing error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reconcileDoses();
      // Pick up changes made on another phone, at most every 10 minutes.
      final last = _lastCloudSync;
      if (last == null || DateTime.now().difference(last) > const Duration(minutes: 10)) {
        _lastCloudSync = DateTime.now();
        runCloudSync(ref);
      }
    }
  }

  /// Marks overdue, never-acknowledged doses as missed and rebuilds the alarm schedule.
  /// Rebuilding on resume also restores alarms if the OS dropped them (e.g. after the
  /// app was force-stopped or the phone's clock/time zone changed).
  void _reconcileDoses() {
    if (!mounted) return;
    if (ref.read(userUidProvider) == null) return;
    final medicines = ref.read(medicinesProvider);
    if (medicines.isEmpty) return;
    ref.read(doseLogsProvider.notifier).recordMissedDoses(medicines);
    NotificationService.instance.rescheduleAll(medicines, logs: ref.read(doseLogsProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _missedDoseTimer?.cancel();
    _notificationSubscription?.cancel();
    NotificationService.instance.stopForegroundAlarmMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medicines = ref.watch(medicinesProvider);
    final logs = ref.watch(doseLogsProvider);
    NotificationService.instance.startForegroundAlarmMonitoring(medicines, logs: logs);

    // Rebuild alarms whenever medicines change (added, edited, paused, deleted) ...
    // Skipped until the signed-in user's data has loaded, so a brief empty list during
    // start-up never wipes the alarm schedule. (Sign-out cancels alarms explicitly.)
    ref.listen<List<Medicine>>(medicinesProvider, (previous, next) {
      if (ref.read(userUidProvider) == null) return;
      if (next.isNotEmpty) NotificationService.instance.ensurePermissionsRequested();
      NotificationService.instance.rescheduleAll(next, logs: ref.read(doseLogsProvider));
      // Deferred: provider state must not be modified while providers are rebuilding.
      Future.microtask(_reconcileDoses);
    });
    // ... and whenever a dose is logged, so a dose taken early does not ring again today
    // and the daily alarm is restored after the user taps Taken / Remind me later.
    ref.listen<List<DoseLog>>(doseLogsProvider, (previous, next) {
      if (ref.read(userUidProvider) == null) return;
      NotificationService.instance.rescheduleAll(ref.read(medicinesProvider), logs: next);
    });

    final textScale = ref.watch(appSettingsProvider.select((s) => s.textScale));

    return MaterialApp.router(
      title: 'OsudSheba',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      builder: (context, child) {
        // Apply the in-app text size on top of the phone's own accessibility setting,
        // capped so layouts stay usable.
        final mq = MediaQuery.of(context);
        final systemScale = mq.textScaler.scale(16.0) / 16.0;
        final combined = (systemScale * textScale).clamp(1.0, 2.0).toDouble();
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(combined)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
