import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/mock_data_service.dart';
import '../../../../core/utils/dose_slots.dart';
import '../../../../core/utils/time_label.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../shared/widgets/tap_area.dart';

/// Reminder settings: the clock times of the six meal-time slots. Every medicine in a slot
/// rings at that time (one reminder for all of them); changing a time moves them all.
class MealTimesCard extends ConsumerWidget {
  const MealTimesCard({super.key, this.showTitle = true});

  /// False on the Meal times page, whose app bar already says "Meal times".
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final bn = lang == 'bn';

    Future<void> pick(DoseSlot slot) async {
      final m = minutesOfDay(slotTime(slot, settings.slotTimes));
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
        helpText: slot.label(bn),
      );
      if (picked == null) return;
      ref.read(appSettingsProvider.notifier).setSlotTime(slot.key, formatTimeOfDay(picked.hour, picked.minute));
    }

    Widget timeBox(DoseSlot slot) => Expanded(
          child: Semantics(
            button: true,
            label: '${slot.label(bn)}, ${displayTime(slotTime(slot, settings.slotTimes), lang)}',
            hint: bn ? 'সময় বদলাতে চাপুন' : 'Tap to change',
            excludeSemantics: true,
            child: TapArea(
              onTap: () => pick(slot),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.softGreen),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(slot.mealLabel(bn), style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      // The row already names the part of the day: "সকাল ৭:৩০" -> "৭:৩০".
                      child: Text(
                        displayTime(slotTime(slot, settings.slotTimes), lang)
                            .replaceFirst(RegExp(r'^\S+\s(?=\S*[0-9০-৯])'), ''),
                        maxLines: 1,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle) ...[
            Text(
              bn ? 'খাবারের সময়' : 'Meal times',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            bn
                ? 'প্রতিটি সময়ে সেই সময়ের সব ওষুধের জন্য একটিই রিমাইন্ডার বাজবে। সময় বদলালে সেই সময়ের সব ওষুধ সরে যাবে।'
                : 'One reminder rings at each time for all the medicines in it. Changing a time moves all of them.',
            style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.35),
          ),
          for (final part in DayPart.values) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(part.label(bn), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                timeBox(DoseSlot.values[part.index * 2]),
                const SizedBox(width: 8),
                timeBox(DoseSlot.values[part.index * 2 + 1]),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
