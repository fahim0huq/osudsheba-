import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/mock_models.dart';
import '../utils/schedule_utils.dart';
import '../utils/time_utils.dart';
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
  static const String channelDesc = 'High-priority medication reminders and alarms.';

  /// Channel for reminders sent by family (must match the server's push channelId).
  static const String familyChannelId = 'family_reminders';

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
      // Falling back to UTC would make every alarm ring hours early/late (Bangladesh is
      // UTC+6). Pick a zone that matches the phone's current UTC offset instead.
      dev.log('NotificationService: timezone lookup failed ($e); matching by UTC offset.');
      tz.setLocalLocation(_locationForCurrentOffset());
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
      // Reminders a family member sends (push). Separate from medicine alarms, so they never
      // ring like an alarm and can be silenced on their own in Android settings.
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        familyChannelId,
        'Family reminders',
        description: 'Reminders sent by family members who help you with your medicines.',
        importance: Importance.high,
      ));
    }
  }

  tz.Location _locationForCurrentOffset() {
    final offset = DateTime.now().timeZoneOffset;
    if (offset == const Duration(hours: 6)) return tz.getLocation('Asia/Dhaka');
    final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (loc.timeZone(nowUtc).offset == offset.inMilliseconds) return loc;
    }
    return tz.UTC;
  }

  bool _permissionsRequested = false;

  /// Requests notification/alarm permissions at most once per app session.
  Future<void> ensurePermissionsRequested() async {
    if (_permissionsRequested || kIsWeb) return;
    _permissionsRequested = true;
    try {
      await requestPermissions();
    } catch (e) {
      dev.log('NotificationService: permission request failed: $e');
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
      // No full-screen intent: USE_FULL_SCREEN_INTENT is not declared (Play policy).
      fullScreenIntent: false,
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


  // ---------------------------------------------------------------------------
  // Notification IDs
  //
  // Three separate ID spaces so they can never overwrite each other:
  //  * repeating daily alarm for a time slot        -> 'slot|08:00 AM'
  //  * one-off alarm for a slot on a specific date   -> 'day|08:00 AM|20261118'
  //  * snooze for a slot                             -> 'snooze|08:00 AM'
  // (Previously a snooze reused the daily slot ID, which silently replaced the
  // repeating alarm with a one-shot one, and TAKEN cancelled the repeating alarm.)
  // ---------------------------------------------------------------------------

  static int _stableId(String key) {
    // FNV-1a 32-bit: stable across app restarts and Dart versions (String.hashCode is not
    // guaranteed to be), so IDs written by an earlier run can still be cancelled.
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  static String _slotKey(String timeStr) => normalizeTimeString(timeStr) ?? timeStr.trim().toUpperCase();

  /// ID of the repeating daily alarm for a time slot.
  int getTimeSlotNotificationId(String timeStr) => _stableId('slot|${_slotKey(timeStr)}');

  int _dayNotificationId(String timeStr, DateTime day) =>
      _stableId('day|${_slotKey(timeStr)}|${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}');

  int _snoozeNotificationId(String timeStr) => _stableId('snooze|${_slotKey(timeStr)}');

  /// Legacy per-medicine ID (kept so alarms created by older app versions can be cancelled).
  int getNotificationId(String medicineId, String timeStr) {
    return (medicineId.hashCode ^ timeStr.trim().toUpperCase().hashCode) & 0x7FFFFFFF;
  }

  int _legacySlotId(String timeStr) => timeStr.trim().toUpperCase().hashCode & 0x7FFFFFFF;

  /// How far ahead one-off alarms are created for medicines that have an end date.
  /// Kept short because iOS only keeps the 64 nearest pending notifications; alarms are
  /// rebuilt every time the app is opened, so the window keeps moving forward.
  static const int scheduleHorizonDays = 10;

  // ---------------------------------------------------------------------------
  // Grouping
  // ---------------------------------------------------------------------------

  /// Groups medicines due on [day] (default: today) by canonical time slot.
  /// Only active medicines whose start/end dates include [day] are included,
  /// and times are normalised ("8:00 am" and "08:00 AM" share one slot).
  Map<String, List<Medicine>> groupMedicinesByTime(List<Medicine> medicines, {DateTime? day}) {
    final onDay = day ?? DateTime.now();
    final Map<String, List<Medicine>> grouped = {};
    for (final med in medicines) {
      if (!med.isScheduledOn(onDay)) continue;
      for (final timeStr in med.times) {
        final slot = normalizeTimeString(timeStr);
        if (slot == null) {
          dev.log('NotificationService: Unparseable time "$timeStr" for ${med.name}; no alarm can be set for it.');
          continue;
        }
        final list = grouped.putIfAbsent(slot, () => []);
        if (!list.any((m) => m.id == med.id)) list.add(med);
      }
    }
    return grouped;
  }

  // ---------------------------------------------------------------------------
  // Scheduling
  // ---------------------------------------------------------------------------

  Future<void> _serial = Future.value();
  List<Medicine>? _queuedMeds;
  List<DoseLog>? _queuedLogs;
  bool _rescheduleQueued = false;

  /// Rebuilds every medication alarm from the current medicines and today's dose logs.
  ///
  /// Calls are serialised and coalesced: rapid changes (e.g. saving three medicines from a
  /// prescription) result in one consistent rebuild instead of interleaved cancel/schedule
  /// races. Pending snoozes are preserved.
  Future<void> rescheduleAll(List<Medicine> medicines, {List<DoseLog> logs = const []}) {
    if (kIsWeb) return Future.value();
    _queuedMeds = List.of(medicines);
    _queuedLogs = List.of(logs);
    if (_rescheduleQueued) return _serial;
    _rescheduleQueued = true;
    _serial = _serial.then((_) async {
      _rescheduleQueued = false;
      final meds = _queuedMeds ?? const <Medicine>[];
      final lg = _queuedLogs ?? const <DoseLog>[];
      try {
        await _rescheduleNow(meds, lg);
      } catch (e) {
        dev.log('NotificationService Error: reschedule failed: $e');
      }
    });
    return _serial;
  }

  Future<void> _rescheduleNow(List<Medicine> medicines, List<DoseLog> logs) async {
    await _cancelScheduledExceptSnoozes();

    final AppSettings settings = LocalStorageService().getSettings() ?? AppSettings();
    if (!settings.appNotificationsEnabled) {
      await cancelAll(); // includes pending snoozes
      dev.log('NotificationService: Reminders are turned off in settings; no alarms scheduled.');
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);

    // Collect every slot used by any medicine during the horizon.
    final slots = <String>{};
    for (var d = 0; d <= scheduleHorizonDays; d++) {
      slots.addAll(groupMedicinesByTime(medicines, day: today.add(Duration(days: d))).keys);
    }

    var scheduled = 0;
    for (final slot in slots) {
      final t = parseTimeOfDay(slot)!;

      // A medicine is "open-ended" if it has no end date inside the horizon.
      bool isOpenEnded(Medicine m) =>
          m.endDate == null || dateOnly(m.endDate!).isAfter(today.add(const Duration(days: scheduleHorizonDays)));

      int? repeatingFromDay;
      for (var d = 0; d <= scheduleHorizonDays; d++) {
        final day = today.add(Duration(days: d));
        final group = groupMedicinesByTime(medicines, day: day)[slot] ?? const <Medicine>[];
        if (group.isEmpty) continue;

        final fireAt = tz.TZDateTime(tz.local, day.year, day.month, day.day, t.hour, t.minute);
        if (!fireAt.isAfter(now)) continue; // already passed
        if (d == 0 && group.every((m) => hasDoseLog(logs, m.id, slot, day))) {
          continue; // every dose in this slot was already taken/skipped today
        }

        if (group.any(isOpenEnded)) {
          // From here on, a daily repeating alarm covers this slot indefinitely.
          repeatingFromDay = d;
          await _scheduleSlot(
            id: getTimeSlotNotificationId(slot),
            slot: slot,
            medicines: group,
            fireAt: fireAt,
            repeatDaily: true,
            lang: settings.language,
          );
          scheduled++;
          break;
        }

        // Only fixed-course medicines here: schedule a one-off for this specific day,
        // so alarms stop on the course's end date even if the app is never reopened.
        await _scheduleSlot(
          id: _dayNotificationId(slot, day),
          slot: slot,
          medicines: group,
          fireAt: fireAt,
          repeatDaily: false,
          lang: settings.language,
        );
        scheduled++;
      }
      if (repeatingFromDay == null) {
        dev.log('NotificationService: Slot $slot uses one-off alarms (fixed-course medicines).');
      }
    }
    dev.log('NotificationService: Rescheduled $scheduled alarms across ${slots.length} time slots');
  }

  Future<void> _scheduleSlot({
    required int id,
    required String slot,
    required List<Medicine> medicines,
    required tz.TZDateTime fireAt,
    required bool repeatDaily,
    required String lang,
    bool isSnooze = false,
  }) async {
    final medCount = medicines.length;
    final List<String> medSummaryList = medicines.map((m) => '${m.name} ${m.strength}'.trim()).toList();

    final String title;
    if (isSnooze) {
      title = lang == 'bn' ? 'ওষুধ খাওয়ার সময় (আবার মনে করানো হচ্ছে)' : 'Medicine reminder (snoozed)';
    } else {
      title = lang == 'bn'
          ? (medCount > 1 ? 'ওষুধ খাওয়ার সময় ($medCountটি ওষুধ)' : 'ওষুধ খাওয়ার সময় হয়েছে')
          : (medCount > 1 ? 'Time for your medicines ($medCount)' : 'Time for your medicine');
    }
    final String body = lang == 'bn'
        ? 'এখন খাওয়ার সময়: ${medSummaryList.join(", ")}'
        : 'Due now: ${medSummaryList.join(", ")}';

    final String payload = jsonEncode({
      'scheduledTime': slot,
      'medicineId': medicines.first.id,
      'medicineIds': medicines.map((m) => m.id).toList(),
      if (isSnooze) 'isSnooze': true,
    });

    final details = _buildAlarmNotificationDetails(ticker: title);

    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          fireAt,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
          payload: payload,
        );

    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      // Exact alarm permission missing: still schedule, but warn the user in the app.
      exactAlarmsUnavailable = true;
      dev.log('NotificationService Warning: exact alarm failed ($e); falling back to inexact.');
      try {
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (err) {
        dev.log('NotificationService Error: could not schedule alarm $id for $slot: $err');
      }
    }
  }

  /// Set when the OS refused exact alarms; reminders may then arrive several minutes late.
  bool exactAlarmsUnavailable = false;

  Future<void> _cancelScheduledExceptSnoozes() async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        var isSnooze = false;
        final p = request.payload;
        if (p != null) {
          try {
            isSnooze = (jsonDecode(p) as Map<String, dynamic>)['isSnooze'] == true;
          } catch (_) {}
        }
        if (!isSnooze) await _plugin.cancel(request.id);
      }
    } catch (e) {
      // pendingNotificationRequests can fail on some OEM builds; fall back to a full reset.
      dev.log('NotificationService: pending lookup failed ($e); cancelling all.');
      await cancelAll();
    }
  }

  /// Cancel all scheduled alarms in the system
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _plugin.cancelAll();
      dev.log('NotificationService: Cancelled all scheduled notifications');
    } catch (e) {
      dev.log('NotificationService: cancelAll notice: $e');
    }
  }

  /// Cancel alarms that mention a specific medicine (used before a full reschedule).
  Future<void> cancelForMedicine(String medicineId) async {
    if (kIsWeb) return;
    try {
      final List<PendingNotificationRequest> pending = await _plugin.pendingNotificationRequests();
      for (final request in pending) {
        final payloadStr = request.payload;
        if (payloadStr == null) continue;
        try {
          final Map<String, dynamic> data = jsonDecode(payloadStr) as Map<String, dynamic>;
          final List<dynamic>? medIds = data['medicineIds'] as List<dynamic>?;
          if (data['medicineId'] == medicineId || (medIds != null && medIds.contains(medicineId))) {
            await _plugin.cancel(request.id);
          }
        } catch (_) {}
      }
    } catch (e) {
      dev.log('NotificationService Error: Failed to cancel for medicine $medicineId: $e');
    }
  }

  /// Removes the alarm notification currently showing for [timeStr] (and any pending snooze
  /// for it). Call this when the dose is taken, skipped or snoozed, then let
  /// [rescheduleAll] restore future days. Because the visible alarm and the repeating
  /// schedule share an ID on Android, the repeating schedule is also cleared here; the
  /// app's dose-log listener rebuilds it immediately afterwards.
  Future<void> dismissTimeSlot(String timeStr) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    final ids = <int>{
      getTimeSlotNotificationId(timeStr),
      _dayNotificationId(timeStr, now),
      _snoozeNotificationId(timeStr),
      _legacySlotId(timeStr),
    };
    for (final id in ids) {
      try {
        await _plugin.cancel(id);
      } catch (_) {}
    }
  }

  /// Compatibility alias.
  Future<void> cancelForTimeSlot(String timeStr) => dismissTimeSlot(timeStr);

  /// Compatibility wrapper for cancelSpecificNotification
  Future<void> cancelSpecificNotification(String medicineId, String timeStr) async {
    if (kIsWeb) return;
    await dismissTimeSlot(timeStr);
    await _plugin.cancel(getNotificationId(medicineId, timeStr));
  }

  /// Schedules a one-off "snoozed" alarm for a whole time slot in [minutes].
  /// Uses its own ID, so the daily alarm for this slot is never replaced.
  Future<void> scheduleSnoozeForTimeGroup(String scheduledTime, List<Medicine> medicines, int minutes) async {
    if (kIsWeb || medicines.isEmpty) return;
    final slot = _slotKey(scheduledTime);
    final settings = LocalStorageService().getSettings() ?? AppSettings();
    await _scheduleSlot(
      id: _snoozeNotificationId(slot),
      slot: slot,
      medicines: medicines,
      fireAt: tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes)),
      repeatDaily: false,
      lang: settings.language,
      isSnooze: true,
    );
    dev.log('NotificationService: Snooze set for $slot in $minutes minutes');
  }

  /// Compatibility wrapper for scheduleSnooze
  Future<void> scheduleSnooze(Medicine medicine, String timeStr, int minutes) async {
    await scheduleSnoozeForTimeGroup(timeStr, [medicine], minutes);
  }

  /// Debug test notification: schedules a test alarm to fire in 30 seconds
  Future<void> scheduleTestNotification() async {
    if (kIsWeb || !kDebugMode) return;
    await _scheduleTestAlarm(const Duration(seconds: 30));
  }

  /// Schedules a clearly-labelled TEST alarm one minute from now so users and caregivers
  /// can check that alarms ring on this phone (sound, lock screen, battery settings).
  /// The test does not reference real medicines and tapping it never records a dose.
  Future<DateTime> scheduleOneMinuteTestAlarm([List<Medicine> medicines = const []]) async {
    return _scheduleTestAlarm(const Duration(minutes: 1));
  }

  static const int testAlarmId = 999999;

  Future<DateTime> _scheduleTestAlarm(Duration delay) async {
    final scheduledDate = tz.TZDateTime.now(tz.local).add(delay);
    if (kIsWeb) return scheduledDate;
    final settings = LocalStorageService().getSettings() ?? AppSettings();
    final bn = settings.language == 'bn';
    final details = _buildAlarmNotificationDetails(ticker: 'Test alarm');
    final payload = jsonEncode({
      'scheduledTime': formatTimeOfDay(scheduledDate.hour, scheduledDate.minute),
      'medicineId': '',
      'medicineIds': <String>[],
      'isTest': true,
    });
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          testAlarmId,
          bn ? 'পরীক্ষামূলক অ্যালার্ম' : 'Test alarm',
          bn ? 'এটি শুধু একটি পরীক্ষা। আপনার অ্যালার্ম ঠিকমতো কাজ করছে।' : 'This is only a test. Your medicine alarms are working.',
          scheduledDate,
          details,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
    try {
      await schedule(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      exactAlarmsUnavailable = true;
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
    return scheduledDate;
  }

  // ---------------------------------------------------------------------------
  // Foreground monitoring
  // ---------------------------------------------------------------------------

  /// While the app is open, opens the reminder screen as soon as a dose time arrives,
  /// without waiting for the user to tap the notification.
  Timer? _foregroundMonitoringTimer;
  List<Medicine> _monitoredMedicines = [];
  List<DoseLog> _monitoredLogs = [];
  String? _lastTriggeredForegroundMinute;

  void startForegroundAlarmMonitoring(List<Medicine> medicines, {List<DoseLog> logs = const []}) {
    if (kIsWeb) return;
    _monitoredMedicines = medicines;
    _monitoredLogs = logs;
    _foregroundMonitoringTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      _checkForegroundDueMedicines();
    });
  }

  void stopForegroundAlarmMonitoring() {
    _foregroundMonitoringTimer?.cancel();
    _foregroundMonitoringTimer = null;
  }

  void _checkForegroundDueMedicines() {
    if (_monitoredMedicines.isEmpty) return;
    final settings = LocalStorageService().getSettings() ?? AppSettings();
    if (!settings.appNotificationsEnabled) return;

    final now = DateTime.now();
    final currentMinuteKey = '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}';
    if (_lastTriggeredForegroundMinute == currentMinuteKey) return;

    final grouped = groupMedicinesByTime(_monitoredMedicines, day: now);
    for (final entry in grouped.entries) {
      final t = parseTimeOfDay(entry.key);
      if (t == null || t.hour != now.hour || t.minute != now.minute) continue;
      final pending = entry.value.where((m) => !hasDoseLog(_monitoredLogs, m.id, entry.key, now)).toList();
      if (pending.isEmpty) continue;
      _lastTriggeredForegroundMinute = currentMinuteKey;
      selectNotificationPayload.add(jsonEncode({
        'scheduledTime': entry.key,
        'medicineId': pending.first.id,
        'medicineIds': pending.map((m) => m.id).toList(),
      }));
      break;
    }
  }
}
