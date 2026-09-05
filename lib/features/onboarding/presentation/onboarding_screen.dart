import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryLight, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 8.0),
                
                // App Logo with gradient circle
                FadeSlideIn(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.healing_rounded,
                      color: AppColors.primary,
                      size: 52,
                    ),
                  ),
                ),
                const SizedBox(height: 12.0),
                
                // App Title
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: Text(
                    'OsudSheba',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 4.0),
                
                // Slogan
                FadeSlideIn(
                  delay: const Duration(milliseconds: 300),
                  child: const Text(
                    'AI-powered medicine reminder for Bangladesh',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16.0),
                
                // Highlights Section (sequential delays)
                FadeSlideIn(
                  delay: const Duration(milliseconds: 450),
                  child: _buildHighlightCard(
                    context,
                    icon: Icons.document_scanner_rounded,
                    title: 'Understand Prescriptions',
                    description: 'Scan prescription photo using AI to auto-extract schedules.',
                  ),
                ),
                const SizedBox(height: 8.0),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 600),
                  child: _buildHighlightCard(
                    context,
                    icon: Icons.alarm_rounded,
                    title: 'Smart Reminders',
                    description: 'Never miss a dose with app notifications and SMS alerts.',
                  ),
                ),
                const SizedBox(height: 8.0),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 750),
                  child: _buildHighlightCard(
                    context,
                    icon: Icons.people_rounded,
                    title: 'Family Monitoring',
                    description: 'Let caregivers monitor and get alerted when you miss a dose.',
                  ),
                ),
                
                  const Expanded(child: SizedBox(height: 12.0)),
                
                // Bottom Button
                FadeSlideIn(
                  delay: const Duration(milliseconds: 900),
                  child: AppPrimaryButton(
                    text: 'Get Started / শুরু করুন',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => context.go('/language-selection'),
                  ),
                ),
                        const SizedBox(height: 4.0),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        ),
      ),
    ),
  );
}

  Widget _buildHighlightCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.25,
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
