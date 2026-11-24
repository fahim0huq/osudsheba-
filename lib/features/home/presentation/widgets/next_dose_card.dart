import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/utils/dose_text.dart';
import '../../../../core/utils/home_schedule.dart';
import '../../../../core/utils/time_label.dart';
import 'next_dose_visuals.dart';

/// The animated "Next dose" card: time, countdown, the medicines, and Listen / Skip / Taken.
/// Green while waiting, amber when the time has come or passed, a tick when the day is done.
/// Movement stops when the phone's "Remove animations" setting is on.
class NextDoseCard extends StatefulWidget {
  final DoseSlot? slot;
  final DoseMood mood;
  final Duration wait; // until the dose (upcoming) or since it (due / late)
  final String language;
  final VoidCallback onTaken;
  final VoidCallback onSkip;
  final VoidCallback onTap;

  const NextDoseCard({
    super.key,
    required this.slot,
    required this.mood,
    required this.wait,
    required this.language,
    required this.onTaken,
    required this.onSkip,
    required this.onTap,
  });

  @override
  State<NextDoseCard> createState() => _NextDoseCardState();
}

class _NextDoseCardState extends State<NextDoseCard> with TickerProviderStateMixin {
  late final AnimationController _ripple = AnimationController(vsync: this, duration: _rippleSpeed);
  late final AnimationController _drift =
      AnimationController(vsync: this, duration: const Duration(seconds: 7));
  StreamSubscription<TtsState>? _tts;
  bool _speaking = false;
  bool _burst = false;

  bool get _bn => widget.language == 'bn';
  bool get _alert => widget.mood == DoseMood.due || widget.mood == DoseMood.late;
  Duration get _rippleSpeed => Duration(milliseconds: _alert ? 1300 : 2600);

  @override
  void initState() {
    super.initState();
    _speaking = TtsService.instance.isPlaying;
    _tts = TtsService.instance.stateStream.listen((s) {
      if (mounted) setState(() => _speaking = s == TtsState.playing);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(NextDoseCard old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      _ripple.duration = _rippleSpeed;
      _syncMotion();
    }
  }

  void _syncMotion() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _ripple.stop();
      _drift.stop();
    } else {
      _ripple.repeat();
      if (!_drift.isAnimating) _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _tts?.cancel();
    _ripple.dispose();
    _drift.dispose();
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_speaking) {
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

  void _taken() {
    if (_burst) return;
    HapticFeedback.mediumImpact();
    if (MediaQuery.disableAnimationsOf(context)) {
      widget.onTaken();
      return;
    }
    setState(() => _burst = true);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() => _burst = false);
      widget.onTaken();
    });
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final still = MediaQuery.disableAnimationsOf(context);
    final key = '${slot?.scheduledAt}-${widget.mood}';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight, colors: moodColors(widget.mood)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: moodColors(widget.mood)[1].withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(child: DriftGlow(drift: _drift)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: still ? 0 : 450),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(
                      position: Tween(begin: const Offset(0.12, 0), end: Offset.zero).animate(a), child: child),
                ),
                child: KeyedSubtree(key: ValueKey(key), child: _content(slot)),
              ),
            ),
            if (_burst) const Positioned.fill(child: Center(child: TickBurst())),
          ],
        ),
      ),
    );
  }

  Widget _content(DoseSlot? slot) {
    final lang = widget.language;
    final mood = widget.mood;
    if (slot == null) {
      return _header(Icons.event_available_rounded, _bn ? 'আজ কোনো ডোজ নেই' : 'No doses scheduled', null, null);
    }
    final listen = CardButton(
      icon: _speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
      label: _speaking ? (_bn ? 'থামুন' : 'Stop') : (_bn ? 'শুনুন' : 'Listen'),
      onPressed: _toggleAudio,
    );
    if (mood == DoseMood.done) {
      final n = localDigits(slot.medicines.length, lang);
      final when = _bn
          ? 'আগামীকাল ${displayTime(slot.time, lang)} · $nটি ওষুধ'
          : 'Tomorrow ${displayTime(slot.time, lang)} · $n medicine${slot.medicines.length == 1 ? '' : 's'}';
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(Icons.check_rounded, _bn ? 'আজকের সব ডোজ শেষ' : 'All doses done today', null, when),
        const SizedBox(height: 14),
        listen,
      ]);
    }
    final label = switch (mood) {
      DoseMood.due => _bn ? 'এখন খাওয়ার সময়' : 'Time to take',
      DoseMood.late => _bn ? 'এখনো রেকর্ড করা হয়নি' : 'Not recorded yet',
      _ => _bn ? 'পরের ডোজ' : 'Next dose',
    };
    final chip = switch (mood) {
      DoseMood.due => _bn ? 'এখনই' : 'Now',
      DoseMood.late => lateLabel(widget.wait, lang),
      _ => inLabel(widget.wait, lang),
    };
    // Before its time a dose cannot be recorded: Skip and Taken are greyed out.
    final early = mood == DoseMood.upcoming;
    final skip = CardButton(
        icon: Icons.skip_next_rounded, label: _bn ? 'বাদ দিন' : 'Skip', onPressed: early ? null : widget.onSkip);
    final take = CardButton(
      icon: Icons.check_rounded,
      label: _bn ? 'খেয়েছি' : 'Taken',
      onPressed: early ? null : _taken,
      primary: true,
      textColor: _alert ? const Color(0xFF92400E) : AppColors.primaryDark,
    );
    final large = MediaQuery.textScalerOf(context).scale(1.0) > 1.3;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(_alert ? Icons.notifications_active_rounded : Icons.medication_rounded, displayTime(slot.time, lang),
          label, chip),
      const SizedBox(height: 12),
      _medicines(slot),
      const SizedBox(height: 12),
      if (large) ...[
        Row(children: [Expanded(child: listen), const SizedBox(width: 10), Expanded(child: skip)]),
        const SizedBox(height: 10),
        take,
      ] else
        Row(children: [
          Expanded(flex: 4, child: listen),
          const SizedBox(width: 10),
          Expanded(flex: 4, child: skip),
          const SizedBox(width: 10),
          Expanded(flex: 7, child: take),
        ]),
      if (early) ...[
        const SizedBox(height: 8),
        Text(notYetText(slot.time, lang),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    ]);
  }

  Widget _header(IconData icon, String title, String? label, String? chip) {
    return Row(children: [
      RippleIcon(ripple: _ripple, icon: icon, wiggle: _alert),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (label != null)
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92), fontSize: 15, fontWeight: FontWeight.w600)),
          Text(title,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: label == null ? 22 : 30,
                  fontWeight: FontWeight.w800,
                  height: 1.15)),
          if (chip != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
              child: Text(chip,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
      ),
    ]);
  }

  /// The medicines in this slot (up to three, then "+2 more"). Tapping opens the dose screen.
  Widget _medicines(DoseSlot slot) {
    final lang = widget.language;
    final shown = slot.medicines.take(3).toList();
    final more = slot.medicines.length - shown.length;
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final m in shown) ...[
              Text('${m.name} ${m.strength}'.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
              Text(
                  [doseLabel(m, lang), mealLabel(m.mealRelation, lang)].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 15)),
              if (m != shown.last) const SizedBox(height: 6),
            ],
            if (more > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_bn ? 'আরও ${localDigits(more, lang)}টি' : '+$more more',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
          ]),
        ),
      ),
    );
  }
}
