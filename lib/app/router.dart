import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/services/scan/prescription_text_parser.dart';
import '../features/prescription/presentation/photo_entry_screen.dart';
import '../core/constants/app_features.dart';
import '../core/models/mock_models.dart';
import '../core/services/mock_data_service.dart';
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
import '../features/home/presentation/home_screen.dart';
import '../features/medicines/presentation/manage_medicines_screen.dart';
import '../features/medicines/presentation/add_medicine_screen.dart';
import '../features/prescription/presentation/upload_prescription_screen.dart';
import '../features/adherence/presentation/adherence_dashboard_screen.dart';
import '../features/caregiver/presentation/caregiver_dashboard_screen.dart';
import '../features/medicines/presentation/todays_medicines_screen.dart';

import '../features/medicines/presentation/medicine_detail_screen.dart';
import '../features/medicines/presentation/edit_medicine_screen.dart';
import '../features/medicines/presentation/dose_action_screen.dart';

import '../features/prescription/presentation/ai_prescription_review_screen.dart';
import '../features/reminders/presentation/reminder_alert_screen.dart';
import '../features/reminders/presentation/reminder_settings_screen.dart';
import '../features/reminders/presentation/meal_times_screen.dart';

import '../features/adherence/presentation/adherence_history_screen.dart';
import '../features/adherence/presentation/adherence_insights_screen.dart';

import '../features/caregiver/presentation/caregiver_invite_screen.dart';
import '../features/caregiver/presentation/caregiver_patient_detail_screen.dart';
import '../features/caregiver/presentation/caregiver_alerts_screen.dart';
import '../features/family/presentation/invite_family_screen.dart';
import '../features/family/presentation/join_care_screen.dart';
import '../features/family/presentation/care_person_screen.dart';
import '../core/services/family_service.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/privacy_screen.dart';
import '../features/settings/presentation/language_settings_screen.dart';
import '../features/onboarding/presentation/app_startup_gate.dart';
import '../features/medicines/presentation/buy_guide_screen.dart';

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
        '/phone-verification',
        '/forgot-password',
        '/subscription',
        '/reminder-alert',
      ];

      // If route is public, allow
      if (publicRoutes.contains(matched)) {
        if (matched == '/subscription' && authUser != null && isEntitled) {
          final profile = container.read(userProfileProvider);
          if (effectiveRole(profile.role) == 'Caregiver') {
            return '/caregiver';
          }
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
    // The five bottom tabs. Each tab is built once and kept alive, so switching tabs is an
    // instant swap (before, every tap built a whole new page with all five screens).
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MainNavigationScreen(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/add-medicine', builder: (context, state) => const AddMedicineScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/upload-prescription', builder: (context, state) => const UploadPrescriptionScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/my-medicines', builder: (context, state) => const ManageMedicinesScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/caregiver', builder: (context, state) => const CaregiverDashboardScreen())]),
      ],
    ),
    // Report (adherence): opened from Settings.
    GoRoute(
      path: '/adherence',
      builder: (context, state) => const AdherenceDashboardScreen(),
    ),
    // Add Medicine as its own page (with a back arrow), for screens outside the tabs.
    GoRoute(
      path: '/new-medicine',
      builder: (context, state) => const AddMedicineScreen(),
    ),
    GoRoute(
      path: '/medicines',
      builder: (context, state) => TodaysMedicinesScreen(initialTab: state.uri.queryParameters['tab'] == 'all' ? 1 : 0),
    ),
    GoRoute(
      path: '/refill',
      builder: (context, state) => BuyGuideScreen(medicineId: state.uri.queryParameters['medicineId'] ?? ''),
    ),
    GoRoute(
      path: '/medicine-detail',
      builder: (context, state) {
        final med = state.extra is Medicine ? state.extra as Medicine : null;
        return MedicineDetailScreen(medicine: med);
      },
    ),
    GoRoute(
      path: '/edit-medicine',
      builder: (context, state) {
        final med = state.extra is Medicine ? state.extra as Medicine : null;
        return EditMedicineScreen(medicine: med);
      },
    ),
    GoRoute(
      path: '/dose-action',
      builder: (context, state) {
        // extra is lost on app restore / deep links; fall back safely instead of crashing.
        final args = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : const <String, dynamic>{};
        final med = args['medicine'] as Medicine?;
        final time = args['scheduledTime'] as String? ?? '';
        return DoseActionScreen(medicine: med, scheduledTime: time);
      },
    ),
    GoRoute(
      path: '/ai-prescription-review',
      builder: (context, state) {
        final Map<String, dynamic>? args = state.extra is Map<String, dynamic> ? state.extra as Map<String, dynamic> : null;
        return AiPrescriptionReviewScreen(
          ocrText: args?['ocrText'] as String?,
          drafts: args?['drafts'] as List<ScanDraft>?,
          source: args?['source'] as String? ?? 'scan',
        );
      },
    ),
    GoRoute(
      path: '/prescription-photo-entry',
      builder: (context, state) => PhotoEntryScreen(imagePath: state.extra as String? ?? ''),
    ),
    GoRoute(
      path: '/reminder-alert',
      builder: (context, state) {
        final medicineId = state.uri.queryParameters['medicineId'] ?? '';
        final scheduledTime = state.uri.queryParameters['scheduledTime'] ?? '';
        final isTest = state.uri.queryParameters['test'] == '1';
        return ReminderAlertScreen(medicineId: medicineId, scheduledTime: scheduledTime, isTest: isTest);
      },
    ),
    GoRoute(
      path: '/reminder-settings',
      builder: (context, state) => const ReminderSettingsScreen(),
    ),
    GoRoute(
      path: '/meal-times',
      builder: (context, state) => const MealTimesScreen(),
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
    // Family sharing (docs/FAMILY_SHARING_PLAN.md)
    GoRoute(
      path: '/family/invite',
      builder: (context, state) => const InviteFamilyScreen(),
    ),
    GoRoute(
      path: '/family/join',
      builder: (context, state) => const JoinCareScreen(),
    ),
    GoRoute(
      path: '/family/person',
      redirect: (context, state) => state.extra is CaredPerson ? null : '/caregiver',
      builder: (context, state) => CarePersonScreen(person: state.extra! as CaredPerson),
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
      // Kept for old links; the reminder screen now holds all working alarm settings.
      path: '/notification-settings',
      builder: (context, state) => const ReminderSettingsScreen(),
    ),
  ],
);
