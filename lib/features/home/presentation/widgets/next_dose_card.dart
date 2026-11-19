import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/medication_voice_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/utils/home_schedule.dart';
import '../../../../core/utils/dose_text.dart';

/// The "Next dose" card: what to take next, with Listen, Skip and Take buttons.
/// When everything for today is done it says so and shows tomorrow's first dose
/// (without Take/Skip, since tomorrow's dose cannot be recorded yet).
class NextDoseCard extends StatefulWidget {
  final DoseSlot? slot;
  final String language;
  final VoidCallback onTaken;
  final VoidCallback onSkip;
  final VoidCallback onTap;

  const NextDoseCard({
    super.key,
    required this.slot,
    required this.language,
    required this.onTaken,
    required this.onSkip,
    required this.onTap,
  });

  @override
  State<NextDoseCard> createState() => _NextDoseCardState();
}

class _NextDoseCardState extends State<NextDoseCard> {
  StreamSubscription<TtsState>? _ttsSubscription;
  bool _isPlayingTts = false;

  bool get _bn => widget.language == 'bn';

  @override
  void initState() {
    super.initState();
    _isPlayingTts = TtsService.instance.isPlaying;
    _ttsSubscription = TtsService.instance.stateStream.listen((state) {
      if (mounted) setState(() => _isPlayingTts = state == TtsState.playing);
    });
  }

  @override
  void dispose() {
    _ttsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlayingTts) {
      await TtsService.instance.stop();
      return;
    }
    final slot = widget.slot;
    final started = await TtsService.instance.speakHomeSchedule(
      medicines: slot?.medicines ?? const [],
      scheduledTime: slot?.time,
      isTomorrow: slot?.isTomorrow ?? false,
      lang: widget.language,
    );
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_bn
            ? 'কথা বলা যায়নি। ফোনের সেটিংসে Google Text-to-speech ও বাংলা ভয়েস আছে কিনা দেখুন।'
            : 'Could not speak. Check that a text-to-speech voice is installed in the phone settings.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final tomorrow = slot?.isTomorrow ?? false;
    final names = slot == null
        ? ''
        : slot.medicines.map((m) => '${m.name} ${m.strength}'.trim()).join(', ');
    final count = slot?.medicines.length ?? 0;
    final countText = _bn ? MedicationVoiceService.toBanglaDigits('$count') : '$count';

    final String subtitle;
    if (slot == null) {
      subtitle = _bn ? 'কোনো ওষুধের সময় নির্ধারিত নেই' : 'No doses scheduled';
    } else if (tomorrow) {
      subtitle = _bn ? 'আগামীকাল: $names' : 'Tomorrow: $names';
    } else if (count > 1) {
      subtitle = _bn ? 'একসাথে $countTextটি ওষুধ' : '$count medicines together';
    } else {
      final m = slot.medicines.first;
      subtitle = [doseLabel(m, _bn ? 'bn' : 'en'), _meal(m.mealRelation)].where((s) => s.trim().isNotEmpty).join(' • ');
    }

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25), width: 1.2),
      ),
      child: InkWell(
        onTap: slot == null || tomorrow ? null : widget.onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(tomorrow ? Icons.check_circle_rounded : Icons.alarm_rounded,
                      color: tomorrow ? AppColors.success : AppColors.primary, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tomorrow
                          ? (_bn ? 'আজকের সব ডোজ শেষ' : 'All done for today')
                          : (_bn ? 'পরবর্তী ডোজ' : 'Next dose'),
                      style: const TextStyle(
                          color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (slot != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          slot.time, // the line below says "Tomorrow:" when it is tomorrow's dose
                          style: const TextStyle(
                              color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
              if (slot != null && !tomorrow) ...[
                const SizedBox(height: 4),
                Text(
                  names,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              if (slot != null) ...[
                const SizedBox(height: 8),
                _buttons(tomorrow),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buttons(bool tomorrow) {
    final listenColor = _isPlayingTts ? AppColors.error : AppColors.primary;
    final listen = OutlinedButton.icon(
      onPressed: _toggleAudio,
      icon: Icon(_isPlayingTts ? Icons.stop_rounded : Icons.volume_up_rounded, size: 20),
      label: Text(_isPlayingTts ? (_bn ? 'থামুন' : 'Stop') : (_bn ? 'শুনুন' : 'Listen')),
      style: OutlinedButton.styleFrom(
        foregroundColor: listenColor,
        side: BorderSide(color: listenColor.withValues(alpha: 0.5)),
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
    if (tomorrow) return Align(alignment: Alignment.centerLeft, child: listen);
    // At large text sizes three buttons do not fit side by side: Listen goes on its own row.
    final large = MediaQuery.textScalerOf(context).scale(1.0) > 1.3;
    final record = Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onSkip,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            child: Text(_bn ? 'বাদ দিন' : 'Skip', textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: widget.onTaken,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            child: Text(_bn ? 'খেয়েছি' : 'Taken', textAlign: TextAlign.center),
          ),
        ),
      ],
    );
    if (large) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [listen, const SizedBox(height: 8), record]);
    }
    return Row(children: [listen, const SizedBox(width: 8), Expanded(child: record)]);
  }

  String _meal(String meal) {
    if (meal.trim().isEmpty || meal == 'None') return '';
    if (!_bn) return meal;
    return const {'Before Meal': 'খাবারের আগে', 'After Meal': 'খাবারের পরে', 'With Meal': 'খাবারের সাথে'}[meal] ??
        meal;
  }
}
