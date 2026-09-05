import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/auth_user.dart';
import '../../../core/models/mock_models.dart';
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
  }

  void _evaluateRoute(AuthUser? authUser) {
    if (!mounted || _hasNavigated) return;

    // Do not navigate away if an alarm is actively launching or shown
    if (NotificationService.instance.launchPayload != null) {
      return;
    }
    _hasNavigated = true;

    final settings = ref.read(appSettingsProvider);

    // 1. Unauthenticated Routing Check
    if (authUser == null) {
      if (!settings.onboardingCompleted) {
        context.go('/onboarding');
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
    ref.listen<List<Medicine>>(medicinesProvider, (previous, next) {
      NotificationService.instance.rescheduleAll(next);
    });

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
