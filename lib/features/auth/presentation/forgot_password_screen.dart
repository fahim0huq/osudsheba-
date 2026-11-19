import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Before, this only waited 1.5 s and showed "sent" without sending anything.
      await ref.read(authServiceProvider).sendPasswordReset(_emailController.text);
      if (mounted) setState(() => _isSuccess = true);
    } catch (e) {
      if (!mounted) return;
      final bn = ref.read(appSettingsProvider).language == 'bn';
      final text = e.toString();
      final String message;
      if (text.contains('Network')) {
        message = bn ? 'ইন্টারনেট সংযোগ নেই। সংযোগ দেখে আবার চেষ্টা করুন।' : 'No internet connection. Check it and try again.';
      } else if (text.contains('Too many')) {
        message = bn ? 'অনেকবার চেষ্টা করা হয়েছে। কিছুক্ষণ পরে আবার চেষ্টা করুন।' : 'Too many tries. Please wait a while and try again.';
      } else if (text.contains('Invalid email')) {
        message = AppStrings.get('email_invalid', bn ? 'bn' : 'en');
      } else {
        message = bn ? 'লিংক পাঠানো যায়নি। আবার চেষ্টা করুন।' : 'Could not send the link. Please try again.';
      }
      setState(() => _errorMessage = message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('password_reset_title', lang)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      crossFadeState: _isSuccess ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      firstChild: _buildFormView(lang),
                      secondChild: _buildSuccessView(lang),
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

  Widget _buildFormView(String lang) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8.0),
          FadeSlideIn(
            delay: const Duration(milliseconds: 100),
            child: Text(
              AppStrings.get('password_reset_subtitle', lang),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.5,
              ),
            ),
          ),
          const SizedBox(height: 20.0),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16.0),
          ],

          FadeSlideIn(
            delay: const Duration(milliseconds: 200),
            child: Text(
              AppStrings.get('email_label', lang),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 6.0),
          FadeSlideIn(
            delay: const Duration(milliseconds: 300),
            child: TextFormField(
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
          ),
          const Expanded(child: SizedBox(height: 16.0)),

          FadeSlideIn(
            delay: const Duration(milliseconds: 400),
            child: AppPrimaryButton(
              text: AppStrings.get('password_reset_btn', lang),
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _sendResetLink,
            ),
          ),
          const SizedBox(height: 12.0),

          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _isLoading ? null : () => context.pop(),
              child: Text(
                AppStrings.get('back_to_sign_in', lang),
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 14.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8.0),
        ],
      ),
    );
  }

  Widget _buildSuccessView(String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CenterPlaygroundAlign.center,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.success,
            size: 80.0,
          ),
          const SizedBox(height: 24.0),
          Text(
            lang == 'bn' ? 'সফল হয়েছে!' : 'Check your email',
            style: const TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              AppStrings.get('password_reset_sent', lang),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15.0,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const Expanded(child: SizedBox(height: 24.0)),
          AppPrimaryButton(
            text: AppStrings.get('back_to_sign_in', lang),
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}

// Simple alignment helper for crossAxisAlignment
class CenterPlaygroundAlign {
  static const CrossAxisAlignment center = CrossAxisAlignment.center;
}
