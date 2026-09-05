import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/mock_models.dart';
import 'local_storage_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// Payload stored during cold start launch from notification
  String? launchPayload;

  /// Stream controller to expose tap payload responses to the app
  static final StreamController<String?> selectNotificationPayload = StreamController<String?>.broadcast();

  /// Channel ID for high-importance medication alarms
  static const String channelId = 'medication_alarms_channel_v2';
  static const String channelName = 'Medication Alarms';
  static const String channelDesc = 'High-priority full-screen medication reminders and alarms.';

  /// Helper to parse time string (e.g. "08:00 AM") to hour and minute
  Map<String, int>? _parseTime(String timeStr) {
    final RegExp regex = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
    final match = regex.firstMatch(timeStr.trim());
    if (match == null) return null;

    int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    final String ampm = match.group(3)!.toUpperCase();

    if (ampm == 'PM' && hour < 12) {
      hour += 12;
    } else if (ampm == 'AM' && hour == 12) {
      hour = 0;
    }
    return {'hour': hour, 'minute': minute};
  }

  /// Unique notification ID builder per distinct scheduled time slot
  /// Ensures all medicines for that time slot share the same single notification alert.
  int getTimeSlotNotificationId(String timeStr) {
    return timeStr.trim().toUpperCase().hashCode & 0x7FFFFFFF;
  }

  /// Unique notification ID for a specific medicine + time slot (fallback / compatibility)
  int getNotificationId(String medicineId, String timeStr) {
    return (medicineId.hashCode ^ timeStr.trim().toUpperCase().hashCode) & 0x7FFFFFFF;
  }

  /// Initialize timezones, platform initialization settings, and channels
  Future<void> init() async {
    if (kIsWeb) return;
    // 1. Timezone initialization
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      dev.log('NotificationService: Local timezone initialized to $timeZoneName');
    } catch (e) {
      dev.log('NotificationService Error: Failed to detect local timezone: $e. Falling back to UTC.');
      tz.setLocalLocation(tz.local);
    }

    // 2. Initialization Settings
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final String? payload = response.payload;
        dev.log('NotificationService: Tap detected with payload: $payload');
        selectNotificationPayload.add(payload);
      },
    );

    // 2.5. Cold start app launch details
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      launchPayload = launchDetails?.notificationResponse?.payload;
      dev.log('NotificationService: App launched from notification with payload: $launchPayload');
    }

    // 3. Android High-Importance Channel Creation with Full Alarm Attributes
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      );
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  /// Request runtime permissions for notifications and exact alarms
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    bool notificationsGranted = false;

    // iOS Request
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final bool? granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      notificationsGranted = granted ?? false;
    }

    // Android Request
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final bool? granted = await androidPlugin.requestNotificationsPermission();
      notificationsGranted = granted ?? false;

      // Request exact alarm permission if compileSdk/targetSdk target Android 12+ (API 31+)
      try {
        await androidPlugin.requestExactAlarmsPermission();
      } catch (e) {
        dev.log('NotificationService: Exact alarm permission request error: $e');
      }
    }

    return notificationsGranted;
  }

  /// Get standard alarm notification details for Android and iOS
  NotificationDetails _buildAlarmNotificationDetails({
    required String ticker,
  }) {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      ongoing: true,
      autoCancel: true,
      ticker: ticker,
      styleInformation: const BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// Group all active medicines by scheduled time string
  Map<String, List<Medicine>> groupMedicinesByTime(List<Medicine> medicines) {
    final Map<String, List<Medicine>> grouped = {};
    for (final med in medicines) {
      if (med.status.toLowerCase() != 'active') continue;
      for (final timeStr in med.times) {
        final cleanTime = timeStr.trim();
        if (cleanTime.isEmpty) continue;
        grouped.putIfAbsent(cleanTime, () => []).add(med);
      }
    }
    return grouped;
  }

  /// Schedule a grouped alarm notification for all medicines due at [scheduledTime]
  Future<void> scheduleForTimeGroup(String scheduledTime, List<Medicine> medicines) async {
    if (kIsWeb || medicines.isEmpty) return;

    // Check if notifications enabled
    final AppSettings settings = LocalStorageService().getSettings() ?? AppSettings();
    if (!settings.appNotificationsEnabled) {
      dev.log('NotificationService: App notifications are disabled. Skipping time group $scheduledTime');
      return;
    }

    final parsed = _parseTime(scheduledTime);
    if (parsed == null) return;

    final int id = getTimeSlotNotificationId(scheduledTime);
    final int hour = parsed['hour']!;
    final int minute = parsed['minute']!;

    // Calculate next instance of this specific time
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // If scheduled time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final String lang = settings.language;
    final int medCount = medicines.length;
    
    // Notification Title & Body
    final String title = lang == 'bn'
        ? (medCount > 1 ? 'ওষুধ খাওয়ার সময় ($medCountটি ওষুধ)' : 'ওষুধ খাওয়ার সময় হয়েছে!')
        : (medCount > 1 ? 'Medication Alarm ($medCount medicines)' : 'Medication Reminder!');

    final List<String> medSummaryList = medicines.map((m) => '${m.name} ${m.strength}'.trim()).toList();
    final String body = lang == 'bn'
        ? 'এখন খাওয়ার সময়: ${medSummaryList.join(", ")}'
        : 'Due now: ${medSummaryList.join(", ")}';

    // Payload JSON with scheduled time and all associated medicine IDs
    final String payload = jsonEncode({
      'scheduledTime': scheduledTime,
      'medicineId': medicines.first.id,
      'medicineIds': medicines.map((m) => m.id).toList(),
    });

    final platformDetails = _buildAlarmNotificationDetails(ticker: title);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      dev.log('NotificationService: Scheduled grouped alarm $id for $scheduledTime with $medCount medicines (Target: $scheduledDate)');
    } catch (e) {
      dev.log('NotificationService Warning: Exact alarms failed ($e). Falling back to inexact scheduling.');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
        dev.log('NotificationService: Scheduled fallback alarm $id for $scheduledTime');
      } catch (err) {
        dev.log('NotificationService Error: Failed to schedule fallback alarm: $err');
      }
    }
  }

  /// Rebuild/reschedule all active alarms grouped by time slot
  Future<void> rescheduleAll(List<Medicine> medicines) async {
    if (kIsWeb) return;
    
    // 1. Cancel all current pending notifications
    await cancelAll();

    // 2. Group active medicines by time slot
    final grouped = groupMedicinesByTime(medicines);

    // 3. Schedule 1 notification per distinct time slot
    for (final entry in grouped.entries) {
      await scheduleForTimeGroup(entry.key, entry.value);
    }
    dev.log('NotificationService: Rescheduled alarms for ${grouped.length} time slots');
  }

  /// Cancel all scheduled alarms in the system
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
    dev.log('NotificationService: Cancelled all scheduled notifications');
  }

  /// Cancel alarms for a specific medicine by inspecting payloads or rescheduling
  Future<void> cancelForMedicine(String medicineId) async {
    if (kIsWeb) return;
    try {
      final List<PendingNotificationRequest> pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        final payloadStr = request.payload;
        if (payloadStr != null) {
          try {
            final Map<String, dynamic> data = jsonDecode(payloadStr) as Map<String, dynamic>;
            final List<dynamic>? medIds = data['medicineIds'] as List<dynamic>?;
            if (data['medicineId'] == medicineId || (medIds != null && medIds.contains(medicineId))) {
              await _plugin.cancel(request.id);
              dev.log('NotificationService: Cancelled notification ${request.id} for medicine $medicineId');
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      dev.log('NotificationService Error: Failed to cancel for medicine $medicineId: $e');
    }
  }

  /// Dismiss/cancel a specific scheduled notification by time slot
  Future<void> cancelForTimeSlot(String timeStr) async {
    if (kIsWeb) return;
    final int id = getTimeSlotNotificationId(timeStr);
    await _plugin.cancel(id);
    dev.log('NotificationService: Cancelled alarm for time slot $timeStr (ID $id)');
  }

  /// Compatibility wrapper for cancelSpecificNotification
  Future<void> cancelSpecificNotification(String medicineId, String timeStr) async {
    if (kIsWeb) return;
    await cancelForTimeSlot(timeStr);
    final int legacyId = getNotificationId(medicineId, timeStr);
    await _plugin.cancel(legacyId);
  }

  /// Schedule a snooze alarm notification for an entire time group in [minutes]
  Future<void> scheduleSnoozeForTimeGroup(String scheduledTime, List<Medicine> medicines, int minutes) async {
    if (kIsWeb || medicines.isEmpty) return;
    final int id = getTimeSlotNotificationId(scheduledTime);

    final platformDetails = _buildAlarmNotificationDetails(ticker: 'Snooze Alarm');
    final tz.TZDateTime scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));

    final String payload = jsonEncode({
      'scheduledTime': scheduledTime,
      'medicineId': medicines.first.id,
      'medicineIds': medicines.map((m) => m.id).toList(),
      'isSnooze': true,
    });

    final AppSettings settings = LocalStorageService().getSettings() ?? AppSettings();
    final String lang = settings.language;
    final int medCount = medicines.length;

    final String title = lang == 'bn'
        ? (medCount > 1 ? 'ওষুধের সময় (স্নুজ - $medCountটি ওষুধ)' : 'ওষুধ খাওয়ার সময়! (পুনরায়)')
        : (medCount > 1 ? 'Medication Alarm (Snoozed - $medCount meds)' : 'Time to take your medicine! (Snoozed)');

    final List<String> medSummaryList = medicines.map((m) => '${m.name} ${m.strength}'.trim()).toList();
    final String body = lang == 'bn'
        ? 'এখন খাওয়ার সময়: ${medSummaryList.join(", ")}'
        : 'Due now: ${medSummaryList.join(", ")}';

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      dev.log('NotificationService: Scheduled snooze alarm $id for $scheduledTime in $minutes minutes');
    } catch (e) {
      dev.log('NotificationService Warning: Exact alarms snooze failed ($e). Falling back to inexact.');
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        dev.log('NotificationService: Scheduled fallback snooze alarm $id in $minutes minutes');
      } catch (err) {
        dev.log('NotificationService Error: Failed to schedule snooze alarm: $err');
      }
    }
  }

  /// Compatibility wrapper for scheduleSnooze
  Future<void> scheduleSnooze(Medicine medicine, String timeStr, int minutes) async {
    await scheduleSnoozeForTimeGroup(timeStr, [medicine], minutes);
  }

  /// Debug test notification: schedules a test alarm to fire in 30 seconds
  Future<void> scheduleTestNotification() async {
    if (kIsWeb || !kDebugMode) return;

    final String title = '🚨 টেস্ট ওষুধ অ্যালার্ম / Test Alarm';
    final String body = 'আপনার Napa 500mg ওষুধ খাওয়ার সময় হয়েছে।';
    const int testId = 999999;

    final platformDetails = _buildAlarmNotificationDetails(ticker: title);
    final tz.TZDateTime scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 30));

    final String payload = jsonEncode({
      'medicineId': 'test_id',
      'scheduledTime': '12:00 PM',
    });

    await _plugin.zonedSchedule(
      testId,
      title,
      body,
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
    dev.log('NotificationService: Scheduled debug test alarm to fire at $scheduledDate');
  }

  /// Foreground Precision Monitoring:
  /// Monitors scheduled medicine times in the foreground so the alarm screen triggers
  /// immediately when the minute arrives, without waiting for the user to tap the notification.
  Timer? _foregroundMonitoringTimer;
  List<Medicine> _monitoredMedicines = [];
  String? _lastTriggeredForegroundMinute;

  void startForegroundAlarmMonitoring(List<Medicine> medicines) {
    if (kIsWeb) return;
    _monitoredMedicines = medicines;
    _foregroundMonitoringTimer?.cancel();
    _foregroundMonitoringTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkForegroundDueMedicines();
    });
  }

  void stopForegroundAlarmMonitoring() {
    _foregroundMonitoringTimer?.cancel();
    _foregroundMonitoringTimer = null;
  }

  void _checkForegroundDueMedicines() {
    if (_monitoredMedicines.isEmpty) return;

    final now = DateTime.now();
    final hour12 = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = now.minute.toString().padLeft(2, '0');
    final formattedNow = '$hour12:$minuteStr $ampm';
    final currentMinuteKey = '${now.year}-${now.month}-${now.day} $formattedNow';

    if (_lastTriggeredForegroundMinute == currentMinuteKey) {
      return; // Already triggered for this exact minute
    }

    final grouped = groupMedicinesByTime(_monitoredMedicines);
    for (final entry in grouped.entries) {
      final scheduledTime = entry.key;
      final parsed = _parseTime(scheduledTime);
      if (parsed != null && parsed['hour'] == now.hour && parsed['minute'] == now.minute) {
        _lastTriggeredForegroundMinute = currentMinuteKey;
        dev.log('NotificationService: Foreground alarm triggered directly for time slot $scheduledTime');
        
        final String payload = jsonEncode({
          'scheduledTime': scheduledTime,
          'medicineId': entry.value.first.id,
          'medicineIds': entry.value.map((m) => m.id).toList(),
        });
        selectNotificationPayload.add(payload);
        break;
      }
    }
  }

  /// Schedule a real 1-minute test alarm for fast deterministic testing
  Future<DateTime> scheduleOneMinuteTestAlarm(List<Medicine> medicines) async {
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = now.add(const Duration(minutes: 1));

    final hour12 = scheduledDate.hour == 0 ? 12 : (scheduledDate.hour > 12 ? scheduledDate.hour - 12 : scheduledDate.hour);
    final ampm = scheduledDate.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = scheduledDate.minute.toString().padLeft(2, '0');
    final scheduledTimeStr = '$hour12:$minuteStr $ampm';

    final targetMeds = medicines.isNotEmpty
        ? medicines
        : [
            Medicine(
              id: 'test_med_id',
              name: 'Napa Extra',
              strength: '500mg',
              dose: '1',
              form: MedicineForm.tablet,
              mealRelation: 'After Meal',
              instruction: 'হালকা গরম পানিতে খেতে পারেন',
              times: [scheduledTimeStr],
              status: 'Active',
            ),
          ];

    final int id = getTimeSlotNotificationId(scheduledTimeStr);
    final platformDetails = _buildAlarmNotificationDetails(ticker: 'Test Alarm ($scheduledTimeStr)');

    final String payload = jsonEncode({
      'scheduledTime': scheduledTimeStr,
      'medicineId': targetMeds.first.id,
      'medicineIds': targetMeds.map((m) => m.id).toList(),
      'isTest': true,
    });

    await _plugin.zonedSchedule(
      id,
      '🚨 টেস্ট ওষুধ অ্যালার্ম (${targetMeds.length}টি ওষুধ)',
      'এখন খাওয়ার সময়: ${targetMeds.map((m) => m.name).join(", ")}',
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    dev.log('NotificationService: Scheduled 1-minute test alarm (ID: $id) for $scheduledTimeStr ($scheduledDate)');
    return scheduledDate;
  }
}

