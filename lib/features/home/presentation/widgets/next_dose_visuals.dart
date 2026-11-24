import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// How the next-dose card looks: waiting (green), due or late (amber), all done (green).
enum DoseMood { upcoming, due, late, done }

const _green = [Color(0xFF059669), AppColors.primary, AppColors.primaryDark];
const _amber = [AppColors.warning, Color(0xFF92400E), Color(0xFF78350F)];

List<Color> moodColors(DoseMood mood) => mood == DoseMood.due || mood == DoseMood.late ? _amber : _green;

/// A soft light that drifts slowly across the card.
class DriftGlow extends StatelessWidget {
  final Animation<double> drift;
  const DriftGlow({super.key, required this.drift});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: drift,
        builder: (context, _) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.lerp(const Alignment(-0.9, -0.9), const Alignment(0.7, 0.3), drift.value)!,
              radius: 0.9,
              colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// The round icon with two rings rippling out of it. When [wiggle] is set the icon
/// (a bell) gives a small shake once per ripple.
class RippleIcon extends StatelessWidget {
  final Animation<double> ripple;
  final IconData icon;
  final bool wiggle;
  const RippleIcon({super.key, required this.ripple, required this.icon, this.wiggle = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: CustomPaint(
        painter: _RipplePainter(ripple),
        child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.2)),
          alignment: Alignment.center,
          child: AnimatedBuilder(
            animation: ripple,
            builder: (context, child) => Transform.rotate(angle: wiggle ? _shake(ripple.value) : 0, child: child),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }

  static double _shake(double t) {
    if (t < 0.6) return 0;
    final p = (t - 0.6) / 0.4; // 0..1
    return math.sin(p * math.pi * 3) * 0.25 * (1 - p);
  }
}

class _RipplePainter extends CustomPainter {
  final Animation<double> ripple;
  _RipplePainter(this.ripple) : super(repaint: ripple);

  @override
  void paint(Canvas canvas, Size size) {
    if (ripple.value == 0 && ripple.status == AnimationStatus.dismissed) return;
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    for (final offset in [0.0, 0.5]) {
      final t = (ripple.value + offset) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.7 * (1 - t));
      canvas.drawCircle(center, r * (1 + 0.75 * t), paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => false;
}

/// The big white tick that pops in when a dose is marked as taken.
class TickBurst extends StatelessWidget {
  const TickBurst({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 64),
      ),
    );
  }
}

/// A button on the card: white and wide for Taken, see-through with the label
/// under the icon for Listen and Skip.
class CardButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final Color textColor;
  const CardButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.textColor = AppColors.primaryDark,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary ? textColor : Colors.white;
    final content = primary
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: fg, size: 26),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.bold)),
          ])
        : Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: fg, size: 22),
            Text(label, style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.bold, height: 1.2)),
          ]);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Material(
        color: primary ? Colors.white : Colors.white.withValues(alpha: 0.14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: primary ? 1 : 0.6), width: 2),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 58,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: content)),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
