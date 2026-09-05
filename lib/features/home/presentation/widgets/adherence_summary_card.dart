import 'package:flutter/material.dart';

class AdherenceSummaryCard extends StatelessWidget {
  final int takenCount;
  final int totalCount;
  final String language;

  const AdherenceSummaryCard({super.key,
    required this.takenCount,
    required this.totalCount,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final double completionRate = totalCount > 0 ? (takenCount / totalCount) : 0;
    final int percentage = (completionRate * 100).toInt();

    final title = language == 'bn' ? 'আজকের অগ্রগতির হার' : 'Today\'s Progress';
    final percentageLabel = '$percentage%';
    
    // Calculate remaining count (for summary stats display)
    final remainingCount = totalCount > takenCount ? (totalCount - takenCount) : 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.0,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9.0, vertical: 3.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Text(
                    percentageLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: LinearProgressIndicator(
                value: completionRate,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 7.0,
              ),
            ),
            const SizedBox(height: 10.0),
            
            // Taken / Remaining stats pills
            Row(
              children: [
                _buildStatPill(
                  icon: Icons.check_circle_rounded,
                  label: language == 'bn' ? 'গৃহীত: $takenCount/$totalCount' : 'Taken: $takenCount/$totalCount',
                  color: Colors.white,
                  textColor: Colors.white,
                ),
                const SizedBox(width: 10.0),
                _buildStatPill(
                  icon: Icons.access_time_rounded,
                  label: language == 'bn' ? 'বাকি: $remainingCount' : 'Remaining: $remainingCount',
                  color: Colors.white.withValues(alpha: 0.8),
                  textColor: Colors.white.withValues(alpha: 0.95),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

