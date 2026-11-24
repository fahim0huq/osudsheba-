import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/mock_data_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/time_label.dart';
import '../../../medicines/presentation/widgets/add_medicine_parts.dart';

/// How many days before a medicine runs out the "time to buy" reminder starts.
class RefillDaysCard extends ConsumerWidget {
  const RefillDaysCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final bn = lang == 'bn';
    Future<void> choose(int d) async {
      ref.read(appSettingsProvider.notifier).setRefillAlertDays(d);
      await NotificationService.instance.rescheduleAll(ref.read(medicinesProvider), logs: ref.read(doseLogsProvider));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  bn ? 'ওষুধ কেনার রিমাইন্ডার' : 'Buy-more reminder',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            bn
                ? 'যেসব ওষুধের স্টক লেখা আছে, সেগুলো শেষ হওয়ার কত দিন আগে মনে করাব:'
                : 'For medicines with a stock count, remind me this many days before they run out:',
            style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          ChoicePills(
            choices: [
              for (final d in const [3, 5, 7])
                PillChoice(
                  bn ? '${localDigits(d, lang)} দিন' : '$d days',
                  selected: settings.refillAlertDays == d,
                  onTap: () => choose(d),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
