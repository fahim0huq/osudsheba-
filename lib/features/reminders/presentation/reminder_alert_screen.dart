import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/utils/schedule_utils.dart';
import '../../../core/utils/time_utils.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../core/utils/dose_text.dart';

class ReminderAlertScreen extends ConsumerStatefulWidget {
  final String medicineId;
  final String scheduledTime;
  /// True for the "test alarm" from Reminder settings: nothing is logged.
  final bool isTest;

  const ReminderAlertScreen({
    super.key,
    required this.medicineId,
    required this.scheduledTime,
    this.isTest = false,
  });

  @override
  ConsumerState<ReminderAlertScreen> createState() => _ReminderAlertScreenState();
}

class _ReminderAlertScreenState extends ConsumerState<ReminderAlertScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  StreamSubscription<TtsState>? _ttsSubscription;
  bool _isPlayingTts = false;
  bool _hasPlayedAutoVoice = false;
  /// Guards against double taps (shaky hands) logging a dose twice or racing navigation.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 4.0, end: 18.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _ttsSubscription = TtsService.instance.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingTts = state == TtsState.playing;
        });
      }
    });

    _isPlayingTts = TtsService.instance.isPlaying;

    // Trigger automatic Bangla voice overview once after first frame render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutomaticVoice();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the phone's "remove animations" accessibility setting.
    if (MediaQuery.of(context).disableAnimations) {
      _pulseController.stop();
      _pulseController.value = 0.5;
    }
  }

  void _triggerAutomaticVoice() {
    if (_hasPlayedAutoVoice || !mounted) return;
    _hasPlayedAutoVoice = true;

    final allMedicines = ref.read(medicinesProvider);
    final settings = ref.read(appSettingsProvider);
    final lang = settings.language;

    final targetMedicines = _resolveTargetMedicines(allMedicines);
    if (targetMedicines.isNotEmpty) {
      TtsService.instance.speakOverview(targetMedicines, lang: lang);
    }
  }

  /// Medicines due in this time slot today that have not been taken or skipped yet.
  List<Medicine> _resolveTargetMedicines(List<Medicine> allMedicines) {
    if (widget.isTest) return const [];
    final now = DateTime.now();
    final logs = ref.read(doseLogsProvider);
    return allMedicines.where((m) {
      if (!m.isScheduledOn(now)) return false;
      if (!m.times.any((t) => sameTimeOfDay(t, widget.scheduledTime))) return false;
      return !hasDoseLog(logs, m.id, widget.scheduledTime, now);
    }).toList();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ttsSubscription?.cancel();
    TtsService.instance.stop();
    super.dispose();
  }

  String _localizeMeal(String mealRelation, String lang) {
    if (lang != 'bn') return mealRelation;
    switch (mealRelation.trim()) {
      case 'Before Meal':
        return 'খাবারের আগে';
      case 'After Meal':
        return 'খাবারের পরে';
      case 'With Meal':
        return 'খাবারের সাথে';
      default:
        return mealRelation.isEmpty ? 'যে কোনো সময়' : mealRelation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final allMedicines = ref.watch(medicinesProvider);

    final List<Medicine> targetMedicines = _resolveTargetMedicines(allMedicines);

    if (targetMedicines.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isTest ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      color: widget.isTest ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                      size: 64.0,
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  Text(
                    widget.isTest
                        ? (lang == 'bn' ? 'পরীক্ষামূলক অ্যালার্ম কাজ করছে' : 'Your test alarm worked')
                        : (lang == 'bn' ? 'এখন কোনো ওষুধ বাকি নেই' : 'Nothing left to take right now'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0, color: Colors.white),
                  ),
                  const SizedBox(height: 10.0),
                  Text(
                    widget.isTest
                        ? (lang == 'bn'
                            ? 'এটি শুধু একটি পরীক্ষা ছিল। কোনো ডোজ রেকর্ড করা হয়নি।'
                            : 'This was only a test. No dose was recorded.')
                        : (lang == 'bn'
                            ? 'এই সময়ের ওষুধ আগেই খাওয়া হয়েছে, বাদ দেওয়া হয়েছে, অথবা তালিকা থেকে সরানো হয়েছে।'
                            : 'The medicines for this time were already taken, skipped, or removed from your list.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17.0, color: Color(0xFFCBD5E1), height: 1.4),
                  ),
                  const SizedBox(height: 32.0),
                  SizedBox(
                    width: double.infinity,
                    height: 56.0,
                    child: AppPrimaryButton(
                      text: lang == 'bn' ? 'হোমে ফিরে যান' : 'Go to Home',
                      icon: Icons.home_rounded,
                      onPressed: () {
                        TtsService.instance.stop();
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/home');
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Future<void> logAll(String status) async {
      for (final med in targetMedicines) {
        ref.read(doseLogsProvider.notifier).addLog(
              DoseLog(
                id: const Uuid().v4(),
                medicineId: med.id,
                medicineName: '${med.name} ${med.strength}'.trim(),
                scheduledTime: normalizeTimeString(widget.scheduledTime) ?? widget.scheduledTime,
                status: status,
                actualTime: DateTime.now(),
              ),
            );
      }
    }

    void leave() {
      if (!context.mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }

    Future<void> onTakenAll() async {
      if (_busy) return;
      setState(() => _busy = true);
      final count = targetMedicines.length;
      await TtsService.instance.stop();
      // Remove the ringing notification; the dose-log listener restores tomorrow's alarm.
      await NotificationService.instance.dismissTimeSlot(widget.scheduledTime);
      await logAll('taken');

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24.0),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  lang == 'bn'
                      ? '$countটি ওষুধ খাওয়া হয়েছে বলে রেকর্ড করা হলো'
                      : (count == 1 ? 'Recorded: medicine taken' : 'Recorded: $count medicines taken'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      leave();
    }

    Future<void> onRemindLaterAll() async {
      if (_busy) return;
      setState(() => _busy = true);
      await TtsService.instance.stop();
      await NotificationService.instance.dismissTimeSlot(widget.scheduledTime);
      // The snooze uses its own alarm ID, so it never replaces the daily alarm.
      await NotificationService.instance.scheduleSnoozeForTimeGroup(
        widget.scheduledTime,
        targetMedicines,
        10,
      );
      await logAll('snoozed');

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.snooze_rounded, color: Colors.white, size: 24.0),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  lang == 'bn'
                      ? '১০ মিনিট পরে আবার মনে করিয়ে দেওয়া হবে'
                      : 'We will remind you again in 10 minutes',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      leave();
    }

    Future<void> toggleTtsDetailed() async {
      if (_isPlayingTts) {
        await TtsService.instance.stop();
      } else {
        final started = await TtsService.instance.speakDetailedInstructions(targetMedicines, lang: lang);
        if (!started && lang == 'bn') {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('আপনার ডিভাইসে বাংলা ভয়েস (TTS) পাওয়া যায়নি।'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    final int count = targetMedicines.length;

    // Header scrolls with the medicine list, so at large text sizes the action buttons
    // below always stay on screen.
    final Widget header = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 20.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF134E4A), Color(0xFF0F172A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.3),
            blurRadius: 20.0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Animated Pulsing Medication Alarm Badge
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF14B8A6).withValues(alpha: 0.6),
                        blurRadius: _glowAnimation.value,
                        spreadRadius: 3.0,
                      ),
                    ],
                  ),
                  child: const Text(
                    '💊',
                    style: TextStyle(fontSize: 42.0),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16.0),

          // Main Alarm Title
          Text(
            lang == 'bn' ? 'ওষুধ খাওয়ার সময়' : 'Time for Medicine',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26.0,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6.0),

          // Alarm Subtitle
          Text(
            lang == 'bn'
                ? 'এখন আপনার ওষুধ খাওয়ার\nসময় হয়েছে।'
                : 'It is time to take your\nscheduled medicines.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF99F6E4),
              fontSize: 16.0,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14.0),

          // Time & Count Badges (Wrap: they stack at large text sizes)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10.0,
            runSpacing: 8.0,
            children: [
              // Scheduled Time Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.alarm_rounded, color: Colors.white, size: 18.0),
                    const SizedBox(width: 6.0),
                    Flexible(
                      child: Text(
                        widget.scheduledTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15.0,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Medicines Count Chip (e.g. "৩টি ওষুধ এখন খেতে হবে")
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF14B8A6).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.5)),
                ),
                child: Text(
                  lang == 'bn' ? '$countটি ওষুধ এখন খেতে হবে' : '$count medicines to take now',
                  style: const TextStyle(
                    color: Color(0xFF5EEAD4),
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium dark alarm background
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable List of Due Medicines
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 12.0),
                itemCount: targetMedicines.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return header;
                  final med = targetMedicines[index - 1];
                  final localizedMeal = _localizeMeal(med.mealRelation, lang);

                  final String subtitle = [
                    if (med.strength.trim().isNotEmpty) med.strength.trim(),
                    doseLabel(med, lang),
                  ].where((s) => s.isNotEmpty).join(' • ');

                  return Container(
                    margin: EdgeInsets.fromLTRB(18.0, index == 1 ? 16.0 : 0.0, 18.0, 12.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(
                        color: const Color(0xFF334155),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8.0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Medicine Form Icon
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF14B8A6).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(med.form.icon, color: const Color(0xFF2DD4BF), size: 26.0),
                        ),
                        const SizedBox(width: 14.0),

                        // Medicine Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name
                              Text(
                                med.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18.0,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4.0),

                              // Strength • Dose (e.g. "500 mg • 1 tablet")
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  fontSize: 14.0,
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              // Meal Relation (e.g. "🍽️ খাবারের পরে")
                              if (med.mealRelation.trim().isNotEmpty && med.mealRelation.trim().toLowerCase() != 'none') ...[
                                const SizedBox(height: 8.0),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF334155),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🍽️', style: TextStyle(fontSize: 13.0)),
                                      const SizedBox(width: 5.0),
                                      Flexible(
                                        child: Text(
                                          localizedMeal,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFE2E8F0),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Instruction (if present)
                              if (med.instruction.trim().isNotEmpty && med.instruction.trim().toLowerCase() != 'null') ...[
                                const SizedBox(height: 8.0),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 14.0,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 5.0),
                                    Expanded(
                                      child: Text(
                                        '${lang == 'bn' ? 'নির্দেশনা' : 'Instruction'}: ${med.instruction.trim()}',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontStyle: FontStyle.italic,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Alarm Actions Section
            Container(
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 20.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28.0),
                  topRight: Radius.circular(28.0),
                ),
                border: const Border(
                  top: BorderSide(color: Color(0xFF334155), width: 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16.0,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔊 Bangla TTS Audio Button [ 🔊 শুনুন ] / [ 🔊 বন্ধ করুন ]
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 56.0),
                    child: OutlinedButton.icon(
                      icon: Icon(
                        _isPlayingTts ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                        color: _isPlayingTts ? const Color(0xFFF87171) : const Color(0xFF2DD4BF),
                        size: 22.0,
                      ),
                      label: Text(
                        _isPlayingTts
                            ? (lang == 'bn' ? 'শোনা বন্ধ করুন' : 'Stop reading')
                            : (lang == 'bn' ? 'শুনুন' : 'Listen'),
                        style: TextStyle(
                          color: _isPlayingTts ? const Color(0xFFF87171) : const Color(0xFF2DD4BF),
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _isPlayingTts ? const Color(0xFFF87171) : const Color(0xFF14B8A6),
                          width: 1.5,
                        ),
                        backgroundColor: _isPlayingTts
                            ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                            : const Color(0xFF0F766E).withValues(alpha: 0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                      ),
                      onPressed: toggleTtsDetailed,
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // [ TAKEN ] Button
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 72.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 32.0),
                      label: Text(
                        lang == 'bn' ? 'খেয়েছি' : 'I took it',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.success.withValues(alpha: 0.5),
                        elevation: 4,
                        shadowColor: AppColors.success.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                      ),
                      onPressed: _busy ? null : onTakenAll,
                    ),
                  ),
                  const SizedBox(height: 10.0),

                  // [ REMIND ME LATER ] Button
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: double.infinity, minHeight: 60.0),
                    child: TextButton.icon(
                      icon: const Icon(Icons.snooze_rounded, color: Color(0xFFFBBF24), size: 26.0),
                      label: Text(
                        lang == 'bn' ? '১০ মিনিট পরে মনে করিয়ে দিন' : 'Remind me in 10 minutes',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.0),
                          side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                        ),
                      ),
                      onPressed: _busy ? null : onRemindLaterAll,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
