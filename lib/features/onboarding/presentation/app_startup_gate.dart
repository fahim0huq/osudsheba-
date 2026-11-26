import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_features.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/auth_user.dart';
import '../../../core/providers/subscription_provider.dart';


class AppStartupGate extends ConsumerStatefulWidget {
  const AppStartupGate({super.key});

  @override
  ConsumerState<AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends ConsumerState<AppStartupGate> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.alarmScreenOpen.addListener(_onAlarmChanged);
  }

  @override
  void dispose() {
    NotificationService.instance.alarmScreenOpen.removeListener(_onAlarmChanged);
    super.dispose();
  }

  /// The alarm screen closed: rebuild, so start-up routing (Home, sign-in...) runs now.
  void _onAlarmChanged() {
    if (mounted && !_hasNavigated && !NotificationService.instance.alarmScreenOpen.value) setState(() {});
  }

  void _evaluateRoute(AuthUser? authUser) {
    if (!mounted || _hasNavigated) return;

    // Do not navigate away while an alarm is launching or shown: that replaced the alarm a
    // moment after it opened over the lock screen. Routing runs once it closes.
    if (NotificationService.instance.launchPayload != null || NotificationService.instance.alarmScreenOpen.value) {
      return;
    }
    _hasNavigated = true;

    var settings = ref.read(appSettingsProvider);

    // Users who chose "Caregiver" before that role was switched off become Patients.
    if (effectiveRole(settings.userRole) != settings.userRole) {
      ref.read(appSettingsProvider.notifier).setRole(effectiveRole(settings.userRole));
      settings = ref.read(appSettingsProvider);
    }

    // 1. Unauthenticated Routing Check
    if (authUser == null) {
      if (!settings.onboardingCompleted) {
        // Language first, so every following screen is in the user's language.
        context.go('/language-selection');
        return;
      }
      if (settings.userRole == 'None') {
        context.go('/role-selection');
        return;
      }
      context.go('/login');
      return;
    }

    // 2. Post-Login Subscription Gate (PREMIUM-ONLY)
    // Every authenticated user must have an active or pending subscription before reaching the app.
    final subAsync = ref.read(subscriptionProvider);
    final isEntitled = subAsync.value?.isEntitled ?? false;
    if (!isEntitled) {
      context.go('/subscription');
      return;
    }

    // 3. Authenticated User Sync & Routing Check
    // Get the user-specific profile (guaranteed to be initialized at this point)
    final profileNotifier = ref.read(userProfileProvider.notifier);
    var profile = ref.read(userProfileProvider);

    // Sync auth user details (email, name, phone) if empty
    bool needsUpdate = false;
    if (profile.email.isEmpty && authUser.email != null) {
      profile = profile.copyWith(email: authUser.email!);
      needsUpdate = true;
    }
    if (profile.name.isEmpty && authUser.displayName != null) {
      profile = profile.copyWith(name: authUser.displayName!);
      needsUpdate = true;
    }
    if (profile.phone.isEmpty && authUser.phoneNumber != null) {
      profile = profile.copyWith(phone: authUser.phoneNumber!);
      needsUpdate = true;
    }
    if (!profile.isLoggedIn) {
      profile = profile.copyWith(isLoggedIn: true);
      needsUpdate = true;
    }
    if (effectiveRole(profile.role) != profile.role) {
      profile = profile.copyWith(role: effectiveRole(profile.role));
      needsUpdate = true;
    }

    if (needsUpdate) {
      profileNotifier.updateProfile(profile);
    }

    final activeRole = profile.role;

    // A newly authenticated user with role == 'None' must select their role
    if (activeRole == 'None') {
      context.go('/role-selection');
      return;
    }

    // Profile Completion Check
    if (!profile.profileCompleted) {
      if (activeRole == 'Patient') {
        context.go('/patient-profile-setup');
      } else if (activeRole == 'Caregiver') {
        context.go('/caregiver-profile-setup');
      } else {
        context.go('/caregiver-profile-setup');
      }
      return;
    }

    // 4. Everything complete -> Main Navigation
    if (activeRole == 'Caregiver') {
      context.go('/caregiver');
    } else {
      context.go('/home');
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryLight, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.healing_rounded,
                color: AppColors.primary,
                size: 64,
              ),
              SizedBox(height: 16.0),
              Text(
                'OsudSheba',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24.0),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Alarm rescheduling is handled centrally in OsudShebaApp (app.dart).
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (authUser) {
        if (authUser != null) {
          final initAsync = ref.watch(userStorageInitProvider(authUser.uid));
          final subAsync = ref.watch(subscriptionProvider);

          if (initAsync.isLoading || subAsync.isLoading) {
            return _buildLoadingScreen();
          }

          return initAsync.when(
            data: (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _evaluateRoute(authUser);
              });
              return _buildLoadingScreen();
            },
            loading: () => _buildLoadingScreen(),
            error: (e, s) => _buildLoadingScreen(),
          );
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _evaluateRoute(null);
          });
          return _buildLoadingScreen();
        }
      },
      loading: () => _buildLoadingScreen(),
      error: (e, s) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/login');
        });
        return _buildLoadingScreen();
      },
    );
  }
}
