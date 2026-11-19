import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final selectedLang = settings.language;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Language / ভাষা'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20.0),
              FadeSlideIn(
                child: Text(
                  'Select Language\nভাষা নির্বাচন করুন',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                ),
              ),
              const SizedBox(height: 12.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: const Text(
                  'Choose your preferred language for reminders and prescription scanning.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 40.0),
              
              // Bangla Option Card
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: _buildLanguageCard(
                  context,
                  title: 'বাংলা (Bengali)',
                  subtitle: 'রিমাইন্ডার এবং অ্যাপ ব্যবহার করুন বাংলায়',
                  isSelected: selectedLang == 'bn',
                  onTap: () {
                    ref.read(appSettingsProvider.notifier).setLanguage('bn');
                  },
                ),
              ),
              const SizedBox(height: 16.0),
              
              // English Option Card
              FadeSlideIn(
                delay: const Duration(milliseconds: 450),
                child: _buildLanguageCard(
                  context,
                  title: 'English',
                  subtitle: 'Use reminders and app in English',
                  isSelected: selectedLang == 'en',
                  onTap: () {
                    ref.read(appSettingsProvider.notifier).setLanguage('en');
                  },
                ),
              ),
              
              const Spacer(),
              
              FadeSlideIn(
                delay: const Duration(milliseconds: 600),
                child: AppPrimaryButton(
                  text: selectedLang == 'bn' ? 'এগিয়ে যান' : 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    context.go('/onboarding');
                  },
                ),
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryLight : Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.015),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18.0,
                          color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isSelected ? AppColors.primaryDark.withValues(alpha: 0.8) : AppColors.textSecondary,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 2.0,
                    ),
                    color: isSelected ? AppColors.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        )
                      : const SizedBox(width: 14, height: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
