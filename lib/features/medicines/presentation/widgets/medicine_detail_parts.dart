import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/mock_models.dart';
import '../../../../core/services/medication_voice_service.dart';
import '../../../../core/utils/dose_text.dart';
import '../../../../core/utils/time_utils.dart';

/// Compact building blocks of the Medicine Details screen.

const _bnStatus = {
  'taken': 'খাওয়া হয়েছে',
  'snoozed': 'পরে মনে করাবে',
  'skipped': 'বাদ দেওয়া',
  'missed': 'মিস হয়েছে',
  'pending': 'বাকি আছে',
  'not today': 'আজ নয়',
  'paused': 'বন্ধ আছে',
  'completed': 'শেষ হয়েছে',
};

const bnMealNames = {
  'Before Meal': 'খাবারের আগে',
  'After Meal': 'খাবারের পরে',
  'With Meal': 'খাবারের সাথে',
};

/// Icon, name, strength and today's status on one row.
class MedicineDetailHeader extends StatelessWidget {
  final Medicine medicine;
  final String status; // from todayStatusFor
  final bool bn;

  const MedicineDetailHeader({super.key, required this.medicine, required this.status, required this.bn});

  @override
  Widget build(BuildContext context) {
    final key = status.toLowerCase();
    final (Color fg, Color bg) = switch (key) {
      'taken' => (const Color(0xFF059669), const Color(0xFFECFDF5)),
      'missed' => (const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
      'snoozed' => (const Color(0xFFD97706), const Color(0xFFFFFBEB)),
      'skipped' => (Colors.grey.shade700, Colors.grey.shade100),
      _ => (Colors.blue.shade700, const Color(0xFFEFF6FF)),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: Icon(medicine.form.icon, size: 28, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
                ),
                if (medicine.strength.trim().isNotEmpty)
                  Text(
                    medicine.strength,
                    style: const TextStyle(
                        color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    bn ? (_bnStatus[key] ?? status) : status,
                    style: TextStyle(fontWeight: FontWeight.bold, color: fg, fontSize: 13.5),
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

/// Dose, meal, reminder times and instructions, one short line each.
class MedicineDetailFacts extends StatelessWidget {
  final Medicine medicine;
  final bool bn;

  const MedicineDetailFacts({super.key, required this.medicine, required this.bn});

  @override
  Widget build(BuildContext context) {
    final meal = medicine.mealRelation;
    final hasMeal = meal.trim().isNotEmpty && meal != 'None';
    final rows = <(IconData, String, String)>[
      (Icons.tag_rounded, bn ? 'মাত্রা' : 'Dose', doseLabel(medicine, bn ? 'bn' : 'en')),
      if (hasMeal) (Icons.restaurant_rounded, bn ? 'খাবার' : 'Meal', bn ? (bnMealNames[meal] ?? meal) : meal),
      (Icons.alarm_rounded, bn ? 'সময়' : 'Times', medicine.times.join(', ')),
      if (medicine.instruction.trim().isNotEmpty)
        (Icons.notes_rounded, bn ? 'নির্দেশনা' : 'Note', medicine.instruction.trim()),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 10, color: AppColors.border),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(rows[i].$1, color: AppColors.primary, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: '${rows[i].$2}: ',
                        style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: rows[i].$3),
                    ]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Real adherence for this medicine over the last 7 days (replaces a hard-coded
/// "100% adherence" banner). Hidden when nothing has been recorded yet.
class MedicineWeekSummary extends StatelessWidget {
  final int taken;
  final int recorded;
  final bool bn;

  const MedicineWeekSummary({super.key, required this.taken, required this.recorded, required this.bn});

  @override
  Widget build(BuildContext context) {
    if (recorded == 0) return const SizedBox.shrink();
    final good = taken == recorded;
    String n(int v) => bn ? MedicationVoiceService.toBanglaDigits('$v') : '$v';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: good ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(good ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: good ? const Color(0xFF059669) : AppColors.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bn
                  ? 'গত ৭ দিনে: ${n(recorded)}টির মধ্যে ${n(taken)}টি ডোজ খাওয়া হয়েছে'
                  : 'Last 7 days: $taken of $recorded doses taken',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: good ? const Color(0xFF065F46) : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the dose buttons once the selected time is already taken today, so the
/// same dose is not recorded twice. [onUndo] removes the record (for a mistaken tap).
class TakenDoseBanner extends StatelessWidget {
  final DoseLog log;
  final bool bn;
  final VoidCallback onUndo;

  const TakenDoseBanner({super.key, required this.log, required this.bn, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final at = log.actualTime!;
    final time = formatTimeOfDay(at.hour, at.minute);
    final late = log.status == 'late';
    final text = bn
        ? '${MedicationVoiceService.toBanglaDigits(time)}-এ খাওয়া হয়েছে${late ? ' (দেরিতে)' : ''}'
        : 'Taken at $time${late ? ' (late)' : ''}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(bn ? 'ফিরিয়ে নিন' : 'Undo', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
