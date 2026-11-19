import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_features.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // With only one role available there is nothing to choose: continue as Patient.
    if (!kCaregiverRoleEnabled) return const _ContinueAsPatient();

    final settings = ref.watch(appSettingsProvider);
    final profile = ref.watch(userProfileProvider);
    final lang = settings.language;
    final selectedRole = profile.role != 'None' ? profile.role : settings.userRole;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('select_role', lang)),
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
                  AppStrings.get('select_role', lang),
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  lang == 'bn'
                      ? 'আপনার পছন্দসই রোল নির্বাচন করুন যাতে আমরা আপনার জন্য অ্যাপটি সাজাতে পারি।'
                      : 'Choose your profile type so we can customize your dashboard settings.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 36.0),
              
              // Patient Card
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: _buildRoleCard(
                  context,
                  title: AppStrings.get('role_patient', lang),
                  description: AppStrings.get('role_patient_desc', lang),
                  icon: Icons.person_rounded,
                  isSelected: selectedRole == 'Patient',
                  onTap: () {
                    final auth = ref.read(authServiceProvider).currentUser;
                    if (auth != null) {
                      final p = ref.read(userProfileProvider);
                      ref.read(userProfileProvider.notifier).updateProfile(p.copyWith(role: 'Patient'));
                    } else {
                      ref.read(appSettingsProvider.notifier).setRole('Patient');
                    }
                  },
                ),
              ),
              const SizedBox(height: 16.0),
              
              // Caregiver Card
              FadeSlideIn(
                delay: const Duration(milliseconds: 450),
                child: _buildRoleCard(
                  context,
                  title: AppStrings.get('role_caregiver', lang),
                  description: AppStrings.get('role_caregiver_desc', lang),
                  icon: Icons.family_restroom_rounded,
                  isSelected: selectedRole == 'Caregiver',
                  onTap: () {
                    final auth = ref.read(authServiceProvider).currentUser;
                    if (auth != null) {
                      final p = ref.read(userProfileProvider);
                      ref.read(userProfileProvider.notifier).updateProfile(p.copyWith(role: 'Caregiver'));
                    } else {
                      ref.read(appSettingsProvider.notifier).setRole('Caregiver');
                    }
                  },
                ),
              ),
              
              const Spacer(),
              
              FadeSlideIn(
                delay: const Duration(milliseconds: 600),
                child: AppPrimaryButton(
                  text: AppStrings.get('continue_btn', lang),
                  icon: Icons.arrow_forward_rounded,
                  onPressed: selectedRole != 'None'
                      ? () {
                          ref.read(appSettingsProvider.notifier).setOnboardingCompleted(true);
                          final auth = ref.read(authServiceProvider).currentUser;
                          if (auth != null) {
                            final p = ref.read(userProfileProvider);
                            ref.read(userProfileProvider.notifier).updateProfile(p.copyWith(role: selectedRole));
                            if (selectedRole == 'Patient') {
                              context.go('/patient-profile-setup');
                            } else {
                              context.go('/caregiver-profile-setup');
                            }
                          } else {
                            context.go('/login');
                          }
                        }
                      : null, // Disable if no role is selected
                ),
              ),
              const SizedBox(height: 16.0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
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
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                    size: 28.0,
                  ),
                ),
                const SizedBox(width: 16.0),
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
                      const SizedBox(height: 4.0),
                      Text(
                        description,
                        style: TextStyle(
                          color: isSelected ? AppColors.primaryDark.withValues(alpha: 0.8) : AppColors.textSecondary,
                          fontSize: 13.0,
                          height: 1.3,
                        ),
                      ),
                    ],
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

/// Used while the Caregiver role is switched off ([kCaregiverRoleEnabled]): records the
/// Patient role and moves on exactly as tapping "Patient" then "Continue" would.
class _ContinueAsPatient extends ConsumerStatefulWidget {
  const _ContinueAsPatient();

  @override
  ConsumerState<_ContinueAsPatient> createState() => _ContinueAsPatientState();
}

class _ContinueAsPatientState extends ConsumerState<_ContinueAsPatient> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(appSettingsProvider.notifier).setRole('Patient');
      ref.read(appSettingsProvider.notifier).setOnboardingCompleted(true);
      final auth = ref.read(authServiceProvider).currentUser;
      if (auth != null) {
        final p = ref.read(userProfileProvider);
        ref.read(userProfileProvider.notifier).updateProfile(p.copyWith(role: 'Patient'));
        context.go(p.profileCompleted ? '/home' : '/patient-profile-setup');
      } else {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
