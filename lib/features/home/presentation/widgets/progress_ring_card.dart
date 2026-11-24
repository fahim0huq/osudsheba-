import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/time_label.dart';

/// Today's progress as a ring: "5/10 taken" in the middle, a sentence beside it.
/// The ring fills smoothly from its last value when a dose is recorded.
class ProgressRingCard extends StatelessWidget {
  final int taken;
  final int total;
  final int left; // doses not taken or skipped yet
  final String language;

  const ProgressRingCard({
    super.key,
    required this.taken,
    required this.total,
    required this.left,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final bn = language == 'bn';
    String d(Object n) => localDigits(n, language);
    final fraction = total == 0 ? 0.0 : (taken / total).clamp(0.0, 1.0);
    final still = MediaQuery.disableAnimationsOf(context);

    final title = total == 0
        ? (bn ? 'আজ কোনো ডোজ নেই' : 'No doses today')
        : (bn ? 'আজ ${d(total)}টির মধ্যে ${d(taken)}টি খাওয়া হয়েছে' : '${d(taken)} of ${d(total)} taken today');
    final sub = total == 0
        ? ''
        : left == 0
            ? (bn ? 'আজকের সব ডোজ শেষ' : 'All done for today')
            : (bn ? 'আর ${d(left)}টি বাকি' : '${d(left)} more to go');

    return Semantics(
      label: '$title. $sub',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction),
                duration: still ? Duration.zero : const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => CustomPaint(painter: _RingPainter(value), child: child),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        child: Text('${d(taken)}/${d(total)}',
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.1)),
                      ),
                      Text(bn ? 'খাওয়া হয়েছে' : 'taken',
                          maxLines: 1,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.3)),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(sub, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFE5E7EB);
    canvas.drawArc(arcRect, 0, 2 * math.pi, false, track);
    if (value <= 0) return;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary;
    canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * value, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}
