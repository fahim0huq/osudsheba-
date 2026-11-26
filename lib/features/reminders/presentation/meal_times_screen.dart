import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import 'widgets/meal_times_card.dart';

/// "Meal times": the clock times of morning / noon / night, before and after meal. Opened
/// from the settings icon beside "When to take" (Add / Edit Medicine); the same card is in
/// Reminder settings. Changing a time moves every medicine in it, and its reminder.
class MealTimesScreen extends ConsumerWidget {
  const MealTimesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bn = ref.watch(appSettingsProvider).language == 'bn';
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F5),
      appBar: AppBar(
        title: Text(bn ? 'খাবারের সময়' : 'Meal times'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const MealTimesCard(showTitle: false),
            const SizedBox(height: 14),
            Text(
              bn
                  ? 'যেমন: সকালে নাস্তা ৯টায় হলে "সকাল · খাবারের পরে" ৯:৩০ করুন। সময়ে চাপ দিয়ে বদলান।'
                  : 'For example, if breakfast is at 9, set "Morning · after meal" to 9:30. Tap a time to change it.',
              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
