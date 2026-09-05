import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_info_card.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    final title = lang == 'bn' ? 'গোপনীয়তা নীতিমালা' : 'Privacy Policy';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                child: Text(
                  lang == 'bn' ? 'আপনার তথ্যের নিরাপত্তা' : 'Your Data Security',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                ),
              ),
              const SizedBox(height: 12.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  lang == 'bn'
                      ? 'ওষুধসেবা আপনার ব্যক্তিগত স্বাস্থ্য সংক্রান্ত তথ্যের সুরক্ষায় প্রতিশ্রুতিবদ্ধ।'
                      : 'OsudSheba is committed to safeguarding your personal health information.',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15.0, fontWeight: FontWeight.w500, height: 1.4),
                ),
              ),
              const SizedBox(height: 28.0),

              // Privacy Items
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: _buildPrivacySection(
                  context,
                  title: lang == 'bn' ? 'স্বাস্থ্য তথ্য সংরক্ষণ' : '1. Health Data Storage',
                  description: lang == 'bn'
                      ? 'আপনার ওষুধের তালিকা এবং ইতিহাস শুধুমাত্র আপনার ফোনেই সংরক্ষিত থাকে। আমরা কোন দূরবর্তী সার্ভারে এগুলো পাঠাই না।'
                      : 'Your medication logs and schedules are stored securely on your local device. We do not sell or track your health data.',
                ),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: _buildPrivacySection(
                  context,
                  title: lang == 'bn' ? 'প্রেসক্রিপশন এআই বিশ্লেষণ' : '2. Prescription Image Scanning',
                  description: lang == 'bn'
                      ? 'আপনার প্রেসক্রিপশনের ছবি প্রসেস করার জন্য আমাদের এআই মডিউল ব্যবহার করা হয়। ছবিগুলো বিশ্লেষণ শেষে সার্ভার থেকে সাথে সাথে মুছে ফেলা হয়।'
                      : 'Prescription photos uploaded for AI analysis are processed dynamically and deleted from the temporary nodes immediately after schedule extraction.',
                ),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: _buildPrivacySection(
                  context,
                  title: lang == 'bn' ? 'তত্ত্বাবধায়কের সাথে তথ্য বিনিময়' : '3. Family Monitoring Link',
                  description: lang == 'bn'
                      ? 'শুধুমাত্র আপনার অনুমোদিত কেয়ারগিভার আপনার ওষুধের অগ্রগতির রিপোর্ট দেখতে পারবে।'
                      : 'Compliance metrics are only shared with caregivers/family members whom you explicitly invite or permit via your dashboard.',
                ),
              ),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: _buildPrivacySection(
                  context,
                  title: lang == 'bn' ? 'তথ্য মুছে ফেলার অনুরোধ' : '4. Data Deletion Request',
                  description: lang == 'bn'
                      ? 'আপনি চাইলে সেটিংস থেকে যেকোনো সময় আপনার সব তথ্য স্থায়ীভাবে মুছে ফেলতে পারেন।'
                      : 'You can delete all application logs and setup details permanently at any time by selecting the clean data option.',
                ),
              ),
              const SizedBox(height: 20.0),

              // Disclaimer Info Card
              FadeSlideIn(
                delay: const Duration(milliseconds: 350),
                child: AppInfoCard(
                  title: lang == 'bn' ? 'মেডিকেল ডিক্লেমার' : 'Medical Disclaimer',
                  description: AppStrings.get('medical_disclaimer', lang),
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.warning,
                  backgroundColor: AppColors.warning.withValues(alpha: 0.06),
                ),
              ),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacySection(BuildContext context, {required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppColors.primary),
          ),
          const SizedBox(height: 6.0),
          Text(
            description,
            style: const TextStyle(
                  height: 1.45,
                  fontSize: 14.0,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
