import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_primary_button.dart';

/// Shown when the alarm has nothing to take (already recorded, removed) or for the test alarm.
class AlarmEmptyView extends StatelessWidget {
  final bool isTest;
  final String lang;
  final VoidCallback onClose;
  const AlarmEmptyView({super.key, required this.isTest, required this.lang, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final bn = lang == 'bn';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(
                isTest ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: isTest ? const Color(0xFF34D399) : const Color(0xFFFCA5A5),
                size: 64.0,
              ),
            ),
            const SizedBox(height: 24.0),
            Text(
              isTest
                  ? (bn ? 'পরীক্ষামূলক অ্যালার্ম কাজ করছে' : 'Your test alarm worked')
                  : (bn ? 'এখন কোনো ওষুধ বাকি নেই' : 'Nothing left to take right now'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22.0, color: Colors.white),
            ),
            const SizedBox(height: 10.0),
            Text(
              isTest
                  ? (bn
                        ? 'এটি শুধু একটি পরীক্ষা ছিল। কোনো ডোজ রেকর্ড করা হয়নি।'
                        : 'This was only a test. No dose was recorded.')
                  : (bn
                        ? 'এই সময়ের ওষুধ আগেই খাওয়া হয়েছে, বাদ দেওয়া হয়েছে, অথবা তালিকা থেকে সরানো হয়েছে।'
                        : 'The medicines for this time were already taken, skipped, or removed from your list.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17.0, color: Color(0xFFCBD5E1), height: 1.4),
            ),
            const SizedBox(height: 32.0),
            SizedBox(
              width: double.infinity,
              height: 56.0,
              child: AppPrimaryButton(
                text: bn ? 'হোমে ফিরে যান' : 'Go to Home',
                icon: Icons.home_rounded,
                onPressed: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
