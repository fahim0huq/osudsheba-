import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/services/tts_service.dart';

class NextDoseCard extends StatefulWidget {
  final Medicine? nextMedicine;
  final List<Medicine> nextDoseMedicines;
  final String? nextDoseTime;
  final String language;
  final VoidCallback onTaken;
  final VoidCallback onSkip;
  final VoidCallback onTap;

  const NextDoseCard({
    super.key,
    required this.nextMedicine,
    this.nextDoseMedicines = const [],
    required this.nextDoseTime,
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

  @override
  void initState() {
    super.initState();
    _ttsSubscription = TtsService.instance.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingTts = state == TtsState.playing;
        });
      }
    });
    _isPlayingTts = TtsService.instance.isPlaying;
  }

  @override
  void dispose() {
    _ttsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlayingTts) {
      await TtsService.instance.stop();
    } else {
      final medsToAnnounce = widget.nextDoseMedicines.isNotEmpty
          ? widget.nextDoseMedicines
          : (widget.nextMedicine != null ? [widget.nextMedicine!] : <Medicine>[]);

      final started = await TtsService.instance.speakHomeSchedule(
        medicines: medsToAnnounce,
        scheduledTime: widget.nextDoseTime,
        lang: widget.language,
      );

      if (!started && widget.language == 'bn' && mounted) {
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

  @override
  Widget build(BuildContext context) {
    final title = widget.language == 'bn' ? 'পরবর্তী ওষুধের সময়' : 'Next Dose Up';

    if (widget.nextMedicine == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22.0),
          border: Border.all(color: AppColors.border, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 12.0),
            Text(
              widget.language == 'bn' ? 'আজকের সব ওষুধ খাওয়া হয়েছে!' : 'All doses done for today!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: AppColors.textPrimary),
            ),
          ],
        ),
      );
    }

    final int medCount = widget.nextDoseMedicines.isNotEmpty
        ? widget.nextDoseMedicines.length
        : 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22.0),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upper Card Body (tappable for full dose details)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(22.0),
                topRight: Radius.circular(22.0),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 20.0, bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.alarm_rounded, color: AppColors.primary, size: 20.0),
                        ),
                        const SizedBox(width: 10.0),
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 15.0,
                          ),
                        ),
                        const Spacer(),
                        // Time tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Text(
                            widget.nextDoseTime!,
                            style: const TextStyle(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14.0),
                    Text(
                      '${widget.nextMedicine!.name} ${widget.nextMedicine!.strength}',
                      style: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      medCount > 1
                          ? (widget.language == 'bn'
                              ? 'একসাথে $medCountটি ওষুধ খেতে হবে'
                              : '$medCount medicines scheduled together')
                          : 'Dose: ${widget.nextMedicine!.dose} • ${widget.nextMedicine!.mealRelation}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5,
                      ),
                    ),
                    if (widget.nextMedicine!.instruction.isNotEmpty) ...[
                      const SizedBox(height: 6.0),
                      Text(
                        'Instructions: ${widget.nextMedicine!.instruction}',
                        style: const TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Bengali Audio Voice Announcement Button [ 🔊 শুনুন ] / [ ⏹ বন্ধ করুন ]
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            child: SizedBox(
              width: double.infinity,
              height: 40.0,
              child: OutlinedButton.icon(
                icon: Icon(
                  _isPlayingTts ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                  color: _isPlayingTts ? const Color(0xFFEF4444) : AppColors.primary,
                  size: 20.0,
                ),
                label: Text(
                  _isPlayingTts
                      ? (widget.language == 'bn' ? '⏹ বন্ধ করুন' : '⏹ Stop')
                      : (widget.language == 'bn' ? '🔊 শুনুন' : '🔊 Listen'),
                  style: TextStyle(
                    color: _isPlayingTts ? const Color(0xFFEF4444) : AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _isPlayingTts ? const Color(0xFFEF4444) : AppColors.primary.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                  backgroundColor: _isPlayingTts
                      ? const Color(0xFFFEE2E2)
                      : AppColors.primaryLight.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                onPressed: _toggleAudio,
              ),
            ),
          ),
          const SizedBox(height: 10.0),

          // Action Buttons: Skip and Taken
          Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12.0),
                    child: InkWell(
                      onTap: widget.onSkip,
                      borderRadius: BorderRadius.circular(12.0),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: Colors.grey.shade300, width: 1.0),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.language == 'bn' ? 'বাদ দিন' : 'Skip',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12.0),
                    child: InkWell(
                      onTap: widget.onTaken,
                      borderRadius: BorderRadius.circular(12.0),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF0D9488)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.language == 'bn' ? 'খেয়েছি' : 'Take Now',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


