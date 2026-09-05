import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

enum PhoneVerificationStep { phoneInput, otpInput }

class PhoneVerificationScreen extends ConsumerStatefulWidget {
  const PhoneVerificationScreen({super.key});

  @override
  ConsumerState<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends ConsumerState<PhoneVerificationScreen> {
  PhoneVerificationStep _currentStep = PhoneVerificationStep.phoneInput;
  final _phoneFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  String? _errorMessage;

  Timer? _timer;
  int _countdown = 30;

  @override
  void dispose() {
    _phoneController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _countdown = 30;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _nextField(String value, int index) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  void _onOtpChanged(String value, int index) {
    if (value.length > 1) {
      final cleanVal = value.replaceAll(RegExp(r'\D'), '');
      if (cleanVal.length >= 6) {
        for (int i = 0; i < 6; i++) {
          if (i < cleanVal.length) {
            _otpControllers[i].text = cleanVal[i];
          }
        }
        _otpFocusNodes[5].requestFocus();
        _verifyOtp();
      }
    } else {
      _nextField(value, index);
    }
  }

  String? _validateAndFormatNumber(String input) {
    // Clean and keep digits only
    String digits = input.replaceAll(RegExp(r'\D'), '');
    
    // Strip leading country code if present
    if (digits.startsWith('880')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // Must be exactly 10 digits and start with 18 (Robi) or 16 (Airtel)
    if (digits.length != 10 || (!digits.startsWith('18') && !digits.startsWith('16'))) {
      return null;
    }

    return '+880$digits';
  }

  Future<void> _sendCode() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final formattedNumber = _validateAndFormatNumber(_phoneController.text.trim());
    if (formattedNumber == null) {
      setState(() {
        _errorMessage = ref.read(appSettingsProvider).language == 'bn'
            ? 'শুধুমাত্র রবি এবং এয়ারটেল নাম্বার সমর্থিত।'
            : 'Only Robi and Airtel numbers are supported.';
        _isLoading = false;
      });
      return;
    }

    try {
      await ref.read(authServiceProvider).sendPhoneVerification(formattedNumber);
      setState(() {
        _currentStep = PhoneVerificationStep.otpInput;
      });
      _startTimer();
    } catch (e, stackTrace) {
      debugPrint('Send Verification Code Error: $e\n$stackTrace');
      setState(() {
        _errorMessage = _getLocalizedError(e.toString(), ref.read(appSettingsProvider).language);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final formattedNumber = _validateAndFormatNumber(_phoneController.text.trim());
    if (formattedNumber == null) {
      setState(() {
        _errorMessage = ref.read(appSettingsProvider).language == 'bn'
            ? 'শুধুমাত্র রবি এবং এয়ারটেল নাম্বার সমর্থিত।'
            : 'Only Robi and Airtel numbers are supported.';
        _isLoading = false;
      });
      return;
    }

    try {
      await ref.read(authServiceProvider).sendPhoneVerification(formattedNumber);
      _startTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(appSettingsProvider).language == 'bn'
                ? 'কোড আবার পাঠানো হয়েছে'
                : 'Verification code resent!',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Resend Verification Code Error: $e\n$stackTrace');
      setState(() {
        _errorMessage = _getLocalizedError(e.toString(), ref.read(appSettingsProvider).language);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 6) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authServiceProvider).verifyPhoneOtp(code);
      if (mounted) {
        context.go('/');
      }
    } catch (e, stackTrace) {
      debugPrint('Verify Phone OTP Error: $e\n$stackTrace');
      setState(() {
        _errorMessage = _getLocalizedError(e.toString(), ref.read(appSettingsProvider).language);
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
    if (error.contains('Bangladesh phone number') || error.contains('invalid phone number')) {
      return AppStrings.get('phone_invalid', lang);
    }
    if (error.contains('Invalid OTP') || error.contains('verification code')) {
      return AppStrings.get('otp_invalid', lang);
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
      appBar: AppBar(
        title: Text(AppStrings.get('phone_verify_title', lang)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_currentStep == PhoneVerificationStep.otpInput) {
              setState(() {
                _currentStep = PhoneVerificationStep.phoneInput;
                _errorMessage = null;
              });
            } else {
              context.pop();
            }
          },
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
                      crossFadeState: _currentStep == PhoneVerificationStep.phoneInput
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: _buildPhoneInputView(lang),
                      secondChild: _buildOtpInputView(lang),
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

  Widget _buildPhoneInputView(String lang) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8.0),
          FadeSlideIn(
            delay: const Duration(milliseconds: 100),
            child: Text(
              AppStrings.get('phone_verify_subtitle', lang),
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
                      _getLocalizedError(_errorMessage!, lang),
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
              AppStrings.get('phone_label', lang),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: 6.0),

          // Phone field
          FadeSlideIn(
            delay: const Duration(milliseconds: 300),
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: 1.5),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.primary, size: 20),
                prefixText: '+880 ',
                prefixStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                hintText: AppStrings.get('phone_hint', lang),
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 15.0, letterSpacing: 1.0),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppStrings.get('phone_required', lang);
                }
                final formatted = _validateAndFormatNumber(value);
                if (formatted == null) {
                  return lang == 'bn'
                      ? 'শুধুমাত্র রবি এবং এয়ারটেল নাম্বার সমর্থিত।'
                      : 'Only Robi and Airtel numbers are supported.';
                }
                return null;
              },
            ),
          ),
          const Expanded(child: SizedBox(height: 16.0)),

          FadeSlideIn(
            delay: const Duration(milliseconds: 400),
            child: AppPrimaryButton(
              text: AppStrings.get('send_otp', lang),
              isLoading: _isLoading,
              onPressed: _isLoading ? null : _sendCode,
            ),
          ),
          const SizedBox(height: 12.0),

          // Back to Sign In Link
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: _isLoading ? null : () => context.pop(),
              child: Text(
                lang == 'bn' ? 'লগইন স্ক্রিনে ফিরে যান' : 'Back to Sign In',
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

  Widget _buildOtpInputView(String lang) {
    final phoneNum = '+880 ${_phoneController.text}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8.0),
        Text(
          '${AppStrings.get('phone_verify_otp_subtitle', lang)}$phoneNum',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.0,
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
                    _getLocalizedError(_errorMessage!, lang),
                    style: const TextStyle(color: AppColors.error, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16.0),
        ],

        // OTP inputs
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            return SizedBox(
              width: 44.0,
              height: 48.0,
              child: TextFormField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2), // Allow paste trigger
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
                  fillColor: Colors.white,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: AppColors.border, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: AppColors.border, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
                  ),
                ),
                onChanged: (value) => _onOtpChanged(value, index),
              ),
            );
          }),
        ),
        const SizedBox(height: 20.0),

        // Countdown timer & Resend code
        Center(
          child: _countdown > 0
              ? Text(
                  '${AppStrings.get('resend_in', lang)}$_countdown s',
                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 14.0),
                )
              : TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _isLoading ? null : _resendCode,
                  child: Text(
                    AppStrings.get('resend_code', lang),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.0,
                    ),
                  ),
                ),
        ),
        const Expanded(child: SizedBox(height: 16.0)),

        // Verify button
        AppPrimaryButton(
          text: AppStrings.get('verify', lang),
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _verifyOtp,
        ),
        const SizedBox(height: 12.0),

        // Change phone number button
        Center(
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _currentStep = PhoneVerificationStep.phoneInput;
                      _errorMessage = null;
                      // Clear OTPs
                      for (var controller in _otpControllers) {
                        controller.clear();
                      }
                    });
                  },
            child: Text(
              AppStrings.get('change_phone_number', lang),
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
    );
  }
}
