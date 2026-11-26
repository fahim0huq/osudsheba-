import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/schedule_utils.dart';
import '../../../core/utils/time_label.dart';
import '../../../core/utils/time_utils.dart';
import '../../../core/utils/dose_slots.dart';
import 'widgets/alarm_empty_view.dart';
import 'widgets/alarm_controls.dart';
import 'widgets/alarm_medicine_page.dart';

/// The medicine alarm. Opens full screen (over the lock screen when the user chose
/// "Full-screen alarm") or when a reminder is tapped. One page per medicine, with its photo:
/// swipe between them and press Taken on each. "In 10 / 15 min" reminds again later;
/// Close stops the alarm without recording anything.
class ReminderAlertScreen extends ConsumerStatefulWidget {
  final String medicineId;
  final String scheduledTime;

  /// True for the "test alarm" from Reminder settings: nothing is logged.
  final bool isTest;

  const ReminderAlertScreen({super.key, required this.medicineId, required this.scheduledTime, this.isTest = false});

  @override
  ConsumerState<ReminderAlertScreen> createState() => _ReminderAlertScreenState();
}

class _ReminderAlertScreenState extends ConsumerState<ReminderAlertScreen> {
  static const _lockScreen = MethodChannel('com.medisathi.bd.osudsheba/alarm');
  final _pages = PageController();
  StreamSubscription<TtsState>? _tts;
  bool _speaking = false;
  bool _busy = false; // guards double taps (shaky hands)
  int _page = 0;

  /// The medicines due now, fixed when the screen opens so pages do not jump as doses are logged.
  late final List<Medicine> _meds = _resolveDue();
  final Set<String> _taken = {};

  String get _lang => ref.read(appSettingsProvider).language;
  bool get _bn => _lang == 'bn';
  String get _slot => normalizeTimeString(widget.scheduledTime) ?? widget.scheduledTime;
  List<Medicine> get _left => _meds.where((m) => !_taken.contains(m.id)).toList();

  @override
  void initState() {
    super.initState();
    NotificationService.instance.alarmScreenOpen.value = true;
    NotificationService.instance.alarmScreensMounted++;
    _speaking = TtsService.instance.isPlaying;
    _tts = TtsService.instance.stateStream.listen((s) {
      if (mounted) setState(() => _speaking = s == TtsState.playing);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _meds.isNotEmpty) TtsService.instance.speakOverview(_meds, lang: _lang);
    });
  }

  /// Medicines due in this slot today that have not been taken or skipped yet.
  List<Medicine> _resolveDue() {
    if (widget.isTest) return const [];
    final now = DateTime.now();
    final logs = ref.read(doseLogsProvider);
    return ref.read(medicinesProvider).where((m) {
      if (!m.isScheduledOn(now)) return false;
      if (!m.times.any((t) => sameTimeOfDay(t, widget.scheduledTime))) return false;
      return !hasDoseLog(logs, m.id, widget.scheduledTime, now);
    }).toList();
  }

  @override
  void dispose() {
    _tts?.cancel();
    _pages.dispose();
    TtsService.instance.stop();
    _lockScreen.invokeMethod('clearLockScreen').catchError((_) {}); // back behind the lock screen
    // After this frame: the start-up screen may then finish (it waited for the alarm).
    final ns = NotificationService.instance;
    ns.alarmScreensMounted--;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ns.alarmScreensMounted <= 0) ns.alarmScreenOpen.value = false;
    });
    super.dispose();
  }

  void _log(Iterable<Medicine> meds, String status) {
    for (final med in meds) {
      ref
          .read(doseLogsProvider.notifier)
          .addLog(
            DoseLog(
              id: const Uuid().v4(),
              medicineId: med.id,
              medicineName: '${med.name} ${med.strength}'.trim(),
              scheduledTime: _slot,
              status: status,
              actualTime: DateTime.now(),
            ),
          );
    }
  }

  void _leave([String? message, Color? color]) {
    if (!mounted) return;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// Taken for the medicine on screen; moves to the next one still to take, or closes.
  Future<void> _takeOne(Medicine med) async {
    if (_busy || _taken.contains(med.id)) return;
    HapticFeedback.mediumImpact();
    setState(() => _taken.add(med.id));
    _log([med], 'taken');
    if (_left.isEmpty) return _finish();
    final next = _meds.indexWhere((m) => !_taken.contains(m.id));
    await Future.delayed(const Duration(milliseconds: 450));
    if (mounted) _pages.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  Future<void> _takeAll() async {
    if (_busy) return;
    final left = _left;
    setState(() => _taken.addAll(left.map((m) => m.id)));
    _log(left, 'taken');
    await _finish();
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    await TtsService.instance.stop();
    await NotificationService.instance.dismissTimeSlot(widget.scheduledTime);
    final n = localDigits(_taken.length, _lang);
    _leave(_bn ? '$nটি ওষুধ খাওয়া হয়েছে বলে রেকর্ড করা হলো' : 'Recorded: $n taken', AppColors.success);
  }

  Future<void> _snooze(int minutes) async {
    if (_busy) return;
    setState(() => _busy = true);
    final left = _left;
    await TtsService.instance.stop();
    await NotificationService.instance.dismissTimeSlot(widget.scheduledTime);
    // Its own alarm ID, so the daily alarm is never replaced.
    await NotificationService.instance.scheduleSnoozeForTimeGroup(widget.scheduledTime, left, minutes);
    _log(left, 'snoozed');
    final n = localDigits(minutes, _lang);
    _leave(
      _bn ? '$n মিনিট পরে আবার মনে করিয়ে দেওয়া হবে' : 'We will remind you again in $n minutes',
      AppColors.warning,
    );
  }

  /// Stops the alarm without recording anything; the dose stays "not recorded" on Home.
  Future<void> _close() async {
    if (_busy) return;
    setState(() => _busy = true);
    await TtsService.instance.stop();
    if (_meds.isNotEmpty && !widget.isTest) {
      await NotificationService.instance.dismissTimeSlot(widget.scheduledTime);
      // dismissTimeSlot also clears the daily alarm; put tomorrow's back.
      await NotificationService.instance.rescheduleAll(ref.read(medicinesProvider), logs: ref.read(doseLogsProvider));
    }
    _leave();
  }

  Future<void> _listen() async {
    if (_speaking) return TtsService.instance.stop();
    final med = _meds[_page.clamp(0, _meds.length - 1)];
    await TtsService.instance.speakDetailedInstructions([med], lang: _lang);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF065F46), Color(0xFF0F3D33), Color(0xFF0F172A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: _meds.isEmpty
                ? AlarmEmptyView(isTest: widget.isTest, lang: lang, onClose: () => _leave())
                : _alarm(lang),
          ),
        ),
      ),
    );
  }

  Widget _alarm(String lang) {
    final bn = lang == 'bn';
    final count = _meds.length;
    final current = _meds[_page.clamp(0, count - 1)];
    final done = _taken.contains(current.id);
    // Header and buttons grow with the phone's text size only up to 1.15x (they are already
    // large), so the buttons
    // always stay on screen; the medicine page (it scrolls) keeps the full size.
    final full = MediaQuery.of(context);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Column(
        children: [
          // Header: time, title, Listen.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
            child: Row(
              children: [
                const Icon(Icons.alarm_rounded, color: Color(0xFFFBBF24), size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTime(_slot, lang),
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        [
                          ?_slotLabel(bn),
                          count > 1
                              ? (bn ? '${localDigits(count, lang)}টি ওষুধ' : '$count medicines')
                              : (bn ? 'ওষুধ খাওয়ার সময়' : 'Time for your medicine'),
                        ].join(' · '),
                        style: const TextStyle(color: Color(0xFFD1FAE5), fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                RoundAlarmButton(
                  icon: _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                  label: _speaking ? (bn ? 'থামান' : 'Stop') : (bn ? 'শুনুন' : 'Listen'),
                  onTap: _listen,
                ),
              ],
            ),
          ),
          if (count > 1)
            AlarmPageDots(count: count, page: _page, taken: [for (final m in _meds) _taken.contains(m.id)]),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: count,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => MediaQuery(
                data: full,
                child: AlarmMedicinePage(medicine: _meds[i], lang: lang, taken: _taken.contains(_meds[i].id)),
              ),
            ),
          ),
          if (count > 1)
            // ‹ 1 / 3 ›: tap the arrows or swipe to go through the medicines one by one.
            Row(
              children: [
                const SizedBox(width: 8),
                _pageArrow(Icons.chevron_left_rounded, bn ? 'আগের ওষুধ' : 'Previous medicine', _page > 0 ? _page - 1 : null),
                Expanded(
                  child: Text(
                    bn
                        ? '${localDigits(_page + 1, lang)} / ${localDigits(count, lang)} · সরিয়ে বা তীর চেপে দেখুন'
                        : '${_page + 1} of $count · swipe or tap the arrows',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 15),
                  ),
                ),
                _pageArrow(Icons.chevron_right_rounded, bn ? 'পরের ওষুধ' : 'Next medicine', _page < count - 1 ? _page + 1 : null),
                const SizedBox(width: 8),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 62,
                  child: ElevatedButton.icon(
                    onPressed: _busy || done ? null : () => _takeOne(current),
                    icon: const Icon(Icons.check_circle_rounded, size: 30),
                    label: Text(
                      done ? (bn ? 'খাওয়া হয়েছে' : 'Taken') : (bn ? 'খেয়েছি' : 'I took it'),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF14532D),
                      disabledForegroundColor: Colors.white70,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
                ),
                if (_left.length > 1)
                  TextButton(
                    onPressed: _busy ? null : _takeAll,
                    child: Text(
                      bn ? 'বাকি ${localDigits(_left.length, lang)}টিই খেয়েছি' : 'I took all ${_left.length}',
                      style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _laterButton(10, lang)),
                    const SizedBox(width: 10),
                    Expanded(child: _laterButton(15, lang)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _close,
                        style: _outline(Colors.white70),
                        child: Text(bn ? 'বন্ধ করুন' : 'Close', textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "Morning · after meal" when this alarm is a meal-time slot; null for a custom time.
  String? _slotLabel(bool bn) {
    final slot = slotAtTime(_slot, ref.read(appSettingsProvider).slotTimes);
    if (slot == null || !_meds.any((m) => m.slots.contains(slot.key))) return null;
    return slot.label(bn);
  }

  Widget _pageArrow(IconData icon, String label, int? target) => IconButton(
    tooltip: label,
    iconSize: 34,
    color: Colors.white,
    disabledColor: Colors.white24,
    icon: Icon(icon),
    onPressed: target == null
        ? null
        : () => _pages.animateToPage(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
  );

  Widget _laterButton(int minutes, String lang) => OutlinedButton(
    onPressed: _busy ? null : () => _snooze(minutes),
    style: _outline(const Color(0xFFFBBF24)),
    child: Text(
      lang == 'bn' ? '${localDigits(minutes, lang)} মিনিট পরে' : 'In $minutes min',
      textAlign: TextAlign.center,
    ),
  );

  ButtonStyle _outline(Color c) => OutlinedButton.styleFrom(
    foregroundColor: c,
    side: BorderSide(color: c.withValues(alpha: 0.7), width: 2),
    minimumSize: const Size(0, 58),
    padding: const EdgeInsets.symmetric(horizontal: 4),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}
