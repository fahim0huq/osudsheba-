import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/app_primary_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool isSignUp;
  const LoginScreen({super.key, this.isSignUp = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  late bool _isSignUp;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.isSignUp;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleAuthMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _errorMessage = null;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (_isSignUp) {
        await ref.read(authServiceProvider).signUpWithEmail(email, password);
      } else {
        await ref.read(authServiceProvider).signInWithEmail(email, password);
      }

      if (mounted) {
        context.go('/');
      }
    } catch (e, stackTrace) {
      debugPrint('Email Authentication Error: $e\n$stackTrace');
      final settings = ref.read(appSettingsProvider);
      final lang = settings.language;
      setState(() {
        _errorMessage = _getLocalizedError(e.toString(), lang);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      if (mounted) {
        context.go('/');
      }
    } catch (e, stackTrace) {
      debugPrint('Google Sign-In Error: $e\n$stackTrace');
      final settings = ref.read(appSettingsProvider);
      final lang = settings.language;
      setState(() {
        if (e.toString().contains('aborted') || e.toString().contains('canceled') || e.toString().contains('sign_in_failed')) {
          _errorMessage = lang == 'bn' ? 'গুগল সাইন-ইন বাতিল করা হয়েছে।' : 'Google sign-in was canceled by the user.';
        } else {
          _errorMessage = _getLocalizedError(e.toString(), lang);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getLocalizedError(String error, String lang) {
    if (error.contains('Invalid email address') || error.contains('format')) {
      return AppStrings.get('email_invalid', lang);
    }
    if (error.contains('Password must be at least')) {
      return AppStrings.get('password_too_short', lang);
    }
    if (error.contains('Incorrect email or password') || error.contains('wrong-password') || error.contains('user-not-found')) {
      return AppStrings.get('auth_error_invalid_credentials', lang);
    }
    if (error.contains('network') || error.contains('Network error')) {
      return AppStrings.get('auth_error_network', lang);
    }
    return error;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    return Scaffold(
      body: SafeArea(
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
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4.0),
                          // App Title & Slogan
                          const Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.healing_rounded,
                                  color: AppColors.primary,
                                  size: 32,
                                ),
                                SizedBox(height: 4.0),
                                Text(
                                  'OsudSheba',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12.0),

                          // Header State Switcher
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Column(
                              key: ValueKey<bool>(_isSignUp),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isSignUp 
                                      ? AppStrings.get('create_account_title', lang) 
                                      : AppStrings.get('welcome_back', lang),
                                  style: const TextStyle(
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  _isSignUp 
                                      ? AppStrings.get('join_today', lang) 
                                      : AppStrings.get('sign_in_to_continue', lang),
                                  style: const TextStyle(
                                    fontSize: 13.0,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12.0),

                          // Mode Toggle Tab Bar
                          Container(
                            height: 40.0,
                            padding: const EdgeInsets.all(3.0),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_isSignUp) _toggleAuthMode();
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: !_isSignUp ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(7.0),
                                        boxShadow: !_isSignUp
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.05),
                                                  blurRadius: 4.0,
                                                  offset: const Offset(0, 2),
                                                )
                                              ]
                                            : [],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        AppStrings.get('sign_in', lang),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.0,
                                          color: !_isSignUp ? AppColors.primaryDark : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (!_isSignUp) _toggleAuthMode();
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _isSignUp ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(7.0),
                                        boxShadow: _isSignUp
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.05),
                                                  blurRadius: 4.0,
                                                  offset: const Offset(0, 2),
                                                )
                                              ]
                                            : [],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        AppStrings.get('sign_up', lang),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.0,
                                          color: _isSignUp ? AppColors.primaryDark : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12.0),

                          // Error Message Banner
                          if (_errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getLocalizedError(_errorMessage!, lang),
                                      style: const TextStyle(color: AppColors.error, fontSize: 13.0, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10.0),
                          ],

                          // Email Field
                          Text(
                            AppStrings.get('email_label', lang),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4.0),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 14.0, color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: AppStrings.get('email_hint', lang),
                              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary, size: 20),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                  return AppStrings.get('email_required', lang);
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return AppStrings.get('email_invalid', lang);
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10.0),

                          // Password Field
                          Text(
                            AppStrings.get('password_label', lang),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4.0),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: const TextStyle(fontSize: 14.0, color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: _isSignUp 
                                  ? AppStrings.get('password_hint_signup', lang) 
                                  : AppStrings.get('password_hint_login', lang),
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppStrings.get('password_required', lang);
                              }
                              if (_isSignUp && value.length < 6) {
                                return AppStrings.get('password_too_short', lang);
                              }
                              return null;
                            },
                          ),

                          // Confirm Password (SignUp Only)
                          if (_isSignUp) ...[
                            const SizedBox(height: 10.0),
                            Text(
                              AppStrings.get('confirm_password_label', lang),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4.0),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: const TextStyle(fontSize: 14.0, color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: AppStrings.get('confirm_password_hint', lang),
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                              ),
                              validator: (value) {
                                if (_isSignUp) {
                                  if (value == null || value.isEmpty) {
                                    return AppStrings.get('password_confirm_required', lang);
                                  }
                                  if (value != _passwordController.text) {
                                    return AppStrings.get('passwords_do_not_match', lang);
                                  }
                                }
                                return null;
                              },
                            ),
                          ],

                          // Forgot Password (Login Only)
                          if (!_isSignUp) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => context.push('/forgot-password'),
                                child: Text(
                                  AppStrings.get('forgot_password', lang),
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.0,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 10.0),
                          ],

                          // Submit Button
                          AppPrimaryButton(
                            text: _isSignUp 
                                ? AppStrings.get('create_account_btn', lang) 
                                : AppStrings.get('sign_in', lang),
                            isLoading: _isLoading,
                            onPressed: _isLoading ? null : _submit,
                          ),
                          
                          // Spacer/Spacing
                          const SizedBox(height: 12.0),

                          // Divider
                          Row(
                            children: [
                              const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  AppStrings.get('or_continue_with', lang),
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.0),
                                ),
                              ),
                              const Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                            ],
                          ),
                          const SizedBox(height: 10.0),

                          // Google Login Button
                          GestureDetector(
                            onTap: _isLoading ? null : _loginWithGoogle,
                            child: Container(
                              height: 46,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: AppColors.border, width: 1.2),
                              ),
                              alignment: Alignment.center,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CustomPaint(
                                    size: Size(16, 16),
                                    painter: GoogleLogoPainter(),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8.0),

                          // Phone Login Button
                          GestureDetector(
                            onTap: _isLoading ? null : () => context.push('/phone-verification'),
                            child: Container(
                              height: 46,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: AppColors.border, width: 1.2),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.phone_iphone_rounded, color: AppColors.primary, size: 16),
                                  const SizedBox(width: 10),
                                  Text(
                                    AppStrings.get('continue_with_phone', lang),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8.0),

                          // Toggle Text Bottom
                          Center(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: _isLoading ? null : _toggleAuthMode,
                              child: Text(
                                _isSignUp 
                                    ? AppStrings.get('already_have_account', lang) 
                                    : AppStrings.get('dont_have_account', lang),
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}

// Custom Painter to draw a pixel-perfect Google 'G' Icon
class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    
    final double strokeWidth = r * 0.45;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeWidth / 2);
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    // Red: Top arc
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 220 * 3.14159 / 180, 95 * 3.14159 / 180, false, paint);

    // Yellow: Left arc
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 140 * 3.14159 / 180, 80 * 3.14159 / 180, false, paint);

    // Green: Bottom arc
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 45 * 3.14159 / 180, 95 * 3.14159 / 180, false, paint);

    // Blue: Right arc
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, 315 * 3.14159 / 180, 50 * 3.14159 / 180, false, paint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
      
    final double barHeight = strokeWidth;
    final barRect = Rect.fromLTRB(cx - 1, cy - barHeight / 2, cx + r, cy + barHeight / 2);
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
