import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';

/// One compact row in the Home screen's "Today's medicines" list:
/// name and strength, then times and meal, with today's status on the right.
class TodayMedicineTile extends StatelessWidget {
  final Medicine medicine;
  final String status; // from todayStatusFor
  final String language;
  final VoidCallback onTap;

  const TodayMedicineTile({
    super.key,
    required this.medicine,
    required this.status,
    required this.language,
    required this.onTap,
  });

  static const _bnStatus = {
    'taken': 'খাওয়া হয়েছে',
    'snoozed': 'পরে',
    'skipped': 'বাদ',
    'missed': 'মিস',
    'pending': 'বাকি',
    'not today': 'আজ নয়',
    'paused': 'বন্ধ',
    'completed': 'শেষ',
  };

  static const _bnMeal = {
    'Before Meal': 'খাবারের আগে',
    'After Meal': 'খাবারের পরে',
    'With Meal': 'খাবারের সাথে',
  };

  @override
  Widget build(BuildContext context) {
    final bn = language == 'bn';
    final key = status.toLowerCase();
    final (Color color, Color bg, IconData icon) = switch (key) {
      'taken' => (AppColors.success, const Color(0xFFDCFCE7), Icons.check_circle),
      'snoozed' => (AppColors.warning, const Color(0xFFFEF3C7), Icons.snooze),
      'skipped' => (AppColors.textSecondary, const Color(0xFFF3F4F6), Icons.block),
      'missed' => (AppColors.error, const Color(0xFFFEE2E2), Icons.error_outline),
      _ => (AppColors.accent, const Color(0xFFDBEAFE), Icons.schedule),
    };
    final meal = medicine.mealRelation;
    final details = [
      medicine.times.join(', '),
      if (meal.isNotEmpty && meal != 'None') bn ? (_bnMeal[meal] ?? meal) : meal,
    ].where((s) => s.trim().isNotEmpty).join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                Icon(medicine.form.icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${medicine.name} ${medicine.strength}'.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  flex: 0,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: color, size: 15),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            bn ? (_bnStatus[key] ?? status) : status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
