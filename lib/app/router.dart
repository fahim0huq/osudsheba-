import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/models/mock_models.dart';
import '../core/services/auth_service.dart';
import '../core/providers/subscription_provider.dart';

// Import all presentation screens
import '../features/subscription/presentation/subscription_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/onboarding/presentation/language_selection_screen.dart';
import '../features/onboarding/presentation/role_selection_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/phone_verification_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/profile/presentation/patient_profile_setup_screen.dart';
import '../features/profile/presentation/caregiver_profile_setup_screen.dart';
import '../features/home/presentation/main_navigation_screen.dart';
import '../features/medicines/presentation/medicine_list_screen.dart';

import '../features/medicines/presentation/medicine_detail_screen.dart';
import '../features/medicines/presentation/edit_medicine_screen.dart';
import '../features/medicines/presentation/dose_action_screen.dart';

import '../features/prescription/presentation/ai_prescription_review_screen.dart';
import '../features/prescription/presentation/manual_prescription_entry_screen.dart';
import '../features/reminders/presentation/reminder_alert_screen.dart';
import '../features/reminders/presentation/reminder_settings_screen.dart';

import '../features/adherence/presentation/adherence_history_screen.dart';
import '../features/adherence/presentation/adherence_insights_screen.dart';

import '../features/caregiver/presentation/caregiver_invite_screen.dart';
import '../features/caregiver/presentation/caregiver_patient_detail_screen.dart';
import '../features/caregiver/presentation/caregiver_alerts_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/privacy_screen.dart';
import '../features/settings/presentation/language_settings_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/onboarding/presentation/app_startup_gate.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final authUser = container.read(authServiceProvider).currentUser;
      final subState = container.read(subscriptionProvider);
      final isEntitled = subState.value?.isEntitled ?? false;
      final matched = state.matchedLocation;

      const publicRoutes = [
        '/',
        '/onboarding',
        '/language-selection',
        '/role-selection',
        '/login',
        '/signup',
        '/phone-verification',
        '/forgot-password',
        '/subscription',
        '/reminder-alert',
      ];

      // If route is public, allow
      if (publicRoutes.contains(matched)) {
        if (matched == '/subscription' && authUser != null && isEntitled) {
          return '/home';
        }
        return null;
      }

      // Premium route protection:
      // 1. Must be authenticated
      if (authUser == null) {
        return '/login';
      }

      // 2. Must hold active or pending subscription entitlement
      if (!isEntitled) {
        return '/subscription';
      }

      return null;
    } catch (_) {
      return null;
    }
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AppStartupGate(),
    ),
    GoRoute(
      path: '/subscription',
      builder: (context, state) => const SubscriptionScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/language-selection',
      builder: (context, state) => const LanguageSelectionScreen(),
    ),
    GoRoute(
      path: '/role-selection',
      builder: (context, state) => const RoleSelectionScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(isSignUp: false),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const LoginScreen(isSignUp: true),
    ),
    GoRoute(
      path: '/phone-verification',
      builder: (context, state) => const PhoneVerificationScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    GoRoute(
      path: '/patient-profile-setup',
      builder: (context, state) => const PatientProfileSetupScreen(),
    ),
    GoRoute(
      path: '/caregiver-profile-setup',
      builder: (context, state) => const CaregiverProfileSetupScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainNavigationScreen(initialTab: 0),
    ),
    GoRoute(
      path: '/medicines',
      builder: (context, state) => const MedicineListScreen(),
    ),
    GoRoute(
      path: '/add-medicine',
      builder: (context, state) => const MainNavigationScreen(initialTab: 1),
    ),
    GoRoute(
      path: '/medicine-detail',
      builder: (context, state) {
        final med = state.extra as Medicine?;
        return MedicineDetailScreen(medicine: med);
      },
    ),
    GoRoute(
      path: '/edit-medicine',
      builder: (context, state) {
        final med = state.extra as Medicine?;
        return EditMedicineScreen(medicine: med);
      },
    ),
    GoRoute(
      path: '/dose-action',
      builder: (context, state) {
        final Map<String, dynamic> args = state.extra as Map<String, dynamic>;
        final med = args['medicine'] as Medicine?;
        final time = args['scheduledTime'] as String;
        return DoseActionScreen(medicine: med, scheduledTime: time);
      },
    ),
    GoRoute(
      path: '/upload-prescription',
      builder: (context, state) => const MainNavigationScreen(initialTab: 2),
    ),
    GoRoute(
      path: '/ai-prescription-review',
      builder: (context, state) {
        final Map<String, dynamic>? args = state.extra as Map<String, dynamic>?;
        return AiPrescriptionReviewScreen(
          ocrText: args?['ocrText'] as String?,
          draftMedicines: args?['draftMedicines'] as List<Medicine>?,
          isFallback: args?['isFallback'] as bool? ?? false,
        );
      },
    ),
    GoRoute(
      path: '/manual-prescription-entry',
      builder: (context, state) => const ManualPrescriptionEntryScreen(),
    ),
    GoRoute(
      path: '/reminder-alert',
      builder: (context, state) {
        final medicineId = state.uri.queryParameters['medicineId'] ?? '';
        final scheduledTime = state.uri.queryParameters['scheduledTime'] ?? '';
        return ReminderAlertScreen(medicineId: medicineId, scheduledTime: scheduledTime);
      },
    ),
    GoRoute(
      path: '/reminder-settings',
      builder: (context, state) => const ReminderSettingsScreen(),
    ),
    GoRoute(
      path: '/adherence',
      builder: (context, state) => const MainNavigationScreen(initialTab: 3),
    ),
    GoRoute(
      path: '/adherence-history',
      builder: (context, state) => const AdherenceHistoryScreen(),
    ),
    GoRoute(
      path: '/adherence-insights',
      builder: (context, state) => const AdherenceInsightsScreen(),
    ),
    GoRoute(
      path: '/caregiver',
      builder: (context, state) => const MainNavigationScreen(initialTab: 4),
    ),
    GoRoute(
      path: '/caregiver-invite',
      builder: (context, state) => const CaregiverInviteScreen(),
    ),
    GoRoute(
      path: '/caregiver-patient-detail',
      builder: (context, state) => const CaregiverPatientDetailScreen(),
    ),
    GoRoute(
      path: '/caregiver-alerts',
      builder: (context, state) => const CaregiverAlertsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      path: '/language-settings',
      builder: (context, state) => const LanguageSettingsScreen(),
    ),
    GoRoute(
      path: '/notification-settings',
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
  ],
);
