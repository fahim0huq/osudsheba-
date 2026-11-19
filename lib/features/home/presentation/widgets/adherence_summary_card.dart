import 'package:flutter/material.dart';
import '../../../../core/services/medication_voice_service.dart';

/// Today's progress in one compact strip: "Today: 2 of 5 taken", a bar and the percentage.
class AdherenceSummaryCard extends StatelessWidget {
  final int takenCount;
  final int totalCount;
  final String language;

  const AdherenceSummaryCard({
    super.key,
    required this.takenCount,
    required this.totalCount,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final rate = totalCount > 0 ? (takenCount / totalCount).clamp(0.0, 1.0) : 0.0;
    final percent = (rate * 100).round();
    final bn = language == 'bn';
    String n(int v) => bn ? MedicationVoiceService.toBanglaDigits('$v') : '$v';
    final label = bn
        ? 'আজ খাওয়া হয়েছে: ${n(takenCount)}/${n(totalCount)}'
        : 'Today: $takenCount of $totalCount taken';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${n(percent)}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.0),
            child: LinearProgressIndicator(
              value: rate,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6.0,
            ),
          ),
        ],
      ),
    );
  }
}
