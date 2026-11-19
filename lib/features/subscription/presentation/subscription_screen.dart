import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_features.dart';
import '../../../core/models/subscription.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import 'widgets/charge_waiting_card.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isOtpSent = false;
  String _referenceNo = '';
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _countdownTimer;
  int _countdownSeconds = 60;
  bool _canResend = false;

  // After the OTP: the operator is still charging ("pending"). Poll until it unlocks.
  bool _waiting = false;
  bool _waitTimedOut = false;
  bool _polling = false;
  Timer? _pollTimer;
  DateTime? _waitStart;

  @override
  void initState() {
    super.initState();
    // Prefill phone if user has a verified phone number
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authUser = ref.read(authServiceProvider).currentUser;
      if (authUser?.phoneNumber != null && authUser!.phoneNumber!.isNotEmpty) {
        String phone = authUser.phoneNumber!;
        if (phone.startsWith('+880')) {
          phone = '0${phone.substring(4)}';
        } else if (phone.startsWith('880')) {
          phone = '0${phone.substring(3)}';
        }
        _phoneController.text = phone;
      }
      // Came back while the charge is still pending (e.g. after reopening the app): keep
      // waiting for the operator instead of asking for a new OTP.
      if (ref.read(subscriptionProvider).value?.isPending ?? false) _startWaiting();
    });
  }

  void _startWaiting() {
    _pollTimer?.cancel();
    setState(() {
      _waiting = true;
      _waitTimedOut = false;
      _errorMessage = null;
    });
    _waitStart = DateTime.now();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _pollOnce());
  }

  void _stopWaiting() {
    _pollTimer?.cancel();
    setState(() {
      _waiting = false;
      _waitTimedOut = false;
      _isOtpSent = false;
      _otpController.clear();
    });
  }

  Future<void> _pollOnce() async {
    if (_polling) return;
    _polling = true;
    try {
      await ref.read(subscriptionProvider.notifier).refreshStatus();
    } finally {
      _polling = false;
    }
    if (!mounted || !_waiting) return;
    final sub = ref.read(subscriptionProvider).value;
    final bn = ref.read(appSettingsProvider).language == 'bn';
    if (sub?.isEntitled ?? false) {
      _pollTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(bn ? 'অভিনন্দন! ওষুধসেবা প্রিমিয়াম আনলক করা হয়েছে।' : 'Congratulations! OsudSheba Premium unlocked.'),
        backgroundColor: AppColors.success,
      ));
      _goIntoApp();
      return;
    }
    // A real answer that is neither active nor pending: the operator dropped the attempt.
    if (sub != null && !sub.isPending && sub.state != SubscriptionState.error) {
      _stopWaiting();
      setState(() => _errorMessage = bn
          ? 'অপারেটর সাবস্ক্রিপশন চালু করেনি। ব্যালেন্স দেখে আবার চেষ্টা করুন।'
          : 'Your operator did not start the subscription. Check your balance and try again.');
      return;
    }
    if (DateTime.now().difference(_waitStart ?? DateTime.now()) > const Duration(seconds: 90)) {
      _pollTimer?.cancel();
      setState(() => _waitTimedOut = true);
    }
  }

  void _goIntoApp() {
    if (!mounted) return;
    final profile = ref.read(userProfileProvider);
    final caregiver = effectiveRole(profile.role) == 'Caregiver';
    if (!profile.profileCompleted) {
      context.go(caregiver ? '/caregiver-profile-setup' : '/patient-profile-setup');
    } else {
      context.go(caregiver ? '/caregiver' : '/home');
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _countdownSeconds = 60;
      _canResend = false;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        _countdownTimer?.cancel();
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  Future<void> _handleRequestOtp() async {
    final phone = _phoneController.text.trim();
    final lang = ref.read(appSettingsProvider).language;

    if (phone.isEmpty) {
      setState(() {
        _errorMessage = lang == 'bn' ? 'ফোন নম্বর প্রবেশ করান' : 'Please enter your phone number';
      });
      return;
    }

    // Clean digits
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      setState(() {
        _errorMessage = lang == 'bn' ? 'সঠিক মোবাইল নম্বর প্রদান করুন' : 'Please enter a valid mobile number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final refNo = await ref.read(subscriptionProvider.notifier).requestOtp(phone);
      if (!mounted) return;

      if (refNo == 'ALREADY_REGISTERED') {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang == 'bn' 
                ? 'আপনার নম্বরটি ইতিমধ্যে সফলভাবে সাবস্ক্রাইব করা রয়েছে!' 
                : 'Your number is already registered and active!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        final profile = ref.read(userProfileProvider);
        if (!profile.profileCompleted) {
          if (effectiveRole(profile.role) == 'Caregiver') {
            context.go('/caregiver-profile-setup');
          } else {
            context.go('/patient-profile-setup');
          }
        } else {
          if (effectiveRole(profile.role) == 'Caregiver') {
            context.go('/caregiver');
          } else {
            context.go('/home');
          }
        }
        return;
      }

      setState(() {
        _isLoading = false;
        _isOtpSent = true;
        _referenceNo = refNo;
      });
      _startCountdown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    final lang = ref.read(appSettingsProvider).language;

    if (otp.length < 4) {
      setState(() {
        _errorMessage = lang == 'bn' ? 'সঠিক OTP কোড প্রদান করুন' : 'Please enter a valid OTP code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final phone = _phoneController.text.trim();
      final success = await ref.read(subscriptionProvider.notifier).verifyOtp(
        _referenceNo,
        otp,
        phone: phone,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang == 'bn' 
                ? 'অভিনন্দন! ওষুধসেবা প্রিমিয়াম আনলক করা হয়েছে।' 
                : 'Congratulations! OsudSheba Premium unlocked.',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        // Immediate entitlement granted -> Route into the application
        final profile = ref.read(userProfileProvider);
        if (!profile.profileCompleted) {
          if (effectiveRole(profile.role) == 'Caregiver') {
            context.go('/caregiver-profile-setup');
          } else {
            context.go('/patient-profile-setup');
          }
        } else {
          if (effectiveRole(profile.role) == 'Caregiver') {
            context.go('/caregiver');
          } else {
            context.go('/home');
          }
        }
      } else {
        final subState = ref.read(subscriptionProvider).value;
        if (subState?.isPending ?? false) {
          // Not a failure: the operator is still charging. Wait and unlock by itself.
          _startWaiting();
          return;
        }
        final msg = (lang == 'bn'
                ? 'সাবস্ক্রিপশন সক্রিয় করা যায়নি। অনুগ্রহ করে ব্যালেন্স রিচার্জ করে পুনরায় চেষ্টা করুন।'
                : 'Subscription could not be activated. Please check your balance and try again.');
        setState(() {
          _errorMessage = msg;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  Widget _buildBenefitRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20.0),
          ),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final isBn = lang == 'bn';
    final pricingAsync = ref.watch(appPricingInfoProvider);
    final subscriptionState = ref.watch(subscriptionProvider);

    final pricing = pricingAsync.value ?? AppPricingInfo.fallback;
    final currentSub = subscriptionState.value;

    final isCancelled = currentSub?.isCancelled ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isBn ? 'প্রিমিয়াম সাবস্ক্রিপশন' : 'Premium Subscription'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
            tooltip: isBn ? 'লগআউট' : 'Logout',
            onPressed: () async {
              await ref.read(subscriptionProvider.notifier).clear();
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              FadeSlideIn(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 28.0),
                          ),
                          const SizedBox(width: 12.0),
                          Text(
                            isBn ? 'ওষুধসেবা প্রিমিয়াম' : 'OsudSheba Premium',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14.0),
                      Text(
                        isBn 
                          ? 'ওষুধসেবার সকল স্বাস্থ্যসেবা এবং ওষুধ রিমাইন্ডার সুবিধা উপভোগ করতে সাবস্ক্রিপশন আবশ্যক।' 
                          : 'An active subscription is required to access all OsudSheba health and medication features.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '৳${pricing.amount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              isBn ? ' / দিন ' : ' / day ',
                              style: const TextStyle(color: Colors.white70, fontSize: 13.0),
                            ),
                            Text(
                              isBn ? '(রবি ও এয়ারটেল)' : '(Robi & Airtel)',
                              style: const TextStyle(color: Colors.amber, fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20.0),

              // Cancelled Status Alert if applicable
              if (isCancelled)
                FadeSlideIn(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    padding: const EdgeInsets.all(14.0),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.error),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            isBn 
                              ? 'আপনার সাবস্ক্রিপশন বাতিল করা হয়েছে। সেবা চালু রাখতে নিচে নম্বর দিয়ে পুনরায় সাবস্ক্রাইব করুন।' 
                              : 'Your subscription was cancelled. Please subscribe again below to restore access.',
                            style: const TextStyle(color: AppColors.error, fontSize: 13.0, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Premium Benefits List
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Container(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBn ? 'প্রিমিয়াম সুবিধাসমূহ' : 'Premium Features',
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Divider(height: 20.0),
                      _buildBenefitRow(
                        Icons.document_scanner_rounded,
                        isBn ? 'প্রেসক্রিপশন স্ক্যানার' : 'Prescription Scanner',
                        isBn ? 'ডাক্তারের প্রেসক্রিপশন থেকে স্বয়ংক্রিয় রুটিন শনাক্ত' : 'Extract medicine schedules automatically from photos',
                      ),
                      _buildBenefitRow(
                        Icons.alarm_on_rounded,
                        isBn ? 'নির্ভুল ওষুধ রিমাইন্ডার' : 'Reliable Medicine Reminders',
                        isBn ? 'সঠিক সময়ে অ্যালার্ম ও ওষুধ গ্রহণের নিশ্চয়তা' : 'Precise on-time dosage alerts and tracking',
                      ),
                      _buildBenefitRow(
                        Icons.record_voice_over_rounded,
                        isBn ? 'বাংলা ভয়েস নোটিফিকেশন' : 'Bengali Voice Prompts',
                        isBn ? 'বাংলা ভাষায় ওষুধের নাম ও খাবার আগে/পরের নির্দেশনা' : 'Bengali spoken prompts with meal instructions',
                      ),
                      _buildBenefitRow(
                        Icons.family_restroom_rounded,
                        isBn ? 'কেয়ারগিভার ও ফ্যামিলি মনিটরিং' : 'Caregiver & Family Sync',
                        isBn ? 'পরিবারের সদস্যদের ওষুধ খাওয়া রিয়েল-টাইমে জানা' : 'Monitor elderly family members remotely in real time',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20.0),

              // Carrier Billing Box
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sim_card_rounded, color: AppColors.primary, size: 22.0),
                          const SizedBox(width: 8.0),
                          Text(
                            isBn ? 'মোবাইল ব্যালেন্স থেকে সাবস্ক্রিপশন' : 'Direct Carrier Billing',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        isBn 
                          ? 'বিডিঅ্যাপস (BDApps) এর মাধ্যমে রবি ও এয়ারটেল গ্রাহকদের জন্য প্রযোজ্য।' 
                          : 'Powered by BDApps for Robi and Airtel subscribers.',
                        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16.0),

                      // Error message if any
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14.0),
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18.0),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: AppColors.error, fontSize: 13.5),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (_waiting) ...[
                        ChargeWaitingCard(
                          bn: isBn,
                          timedOut: _waitTimedOut,
                          onCheckAgain: _startWaiting,
                          onUseOtherNumber: _stopWaiting,
                        ),
                      ] else if (!_isOtpSent) ...[
                        // Step 1: Phone input
                        Text(
                          isBn ? 'আপনার রবি / এয়ারটেল মোবাইল নম্বর:' : 'Your Robi / Airtel mobile number:',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8.0),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: '018XXXXXXXX বা 016XXXXXXXX',
                            prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.primary),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        AppPrimaryButton(
                          text: isBn ? 'ওটিপি (OTP) পাঠান' : 'Send OTP',
                          isLoading: _isLoading,
                          onPressed: _handleRequestOtp,
                        ),
                      ] else ...[
                        // Step 2: OTP verification
                        Text(
                          isBn 
                            ? '${_phoneController.text} নম্বরে পাঠানো ৬-সংখ্যার OTP কোডটি লিখুন:' 
                            : 'Enter the 6-digit OTP sent to ${_phoneController.text}:',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 8.0),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, letterSpacing: 8.0),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '• • • • • •',
                            hintStyle: const TextStyle(letterSpacing: 8.0, color: Colors.black26),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12.0),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _isLoading ? null : () {
                                setState(() {
                                  _isOtpSent = false;
                                  _otpController.clear();
                                  _errorMessage = null;
                                });
                              },
                              child: Text(
                                isBn ? 'নম্বর পরিবর্তন করুন' : 'Change Number',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.0),
                              ),
                            ),
                            TextButton(
                              onPressed: (_canResend && !_isLoading) ? _handleRequestOtp : null,
                              child: Text(
                                _canResend 
                                  ? (isBn ? 'পুনরায় কোড পাঠান' : 'Resend Code')
                                  : '${isBn ? 'পুনরায় পাঠান' : 'Resend in'} ($_countdownSeconds s)',
                                style: TextStyle(
                                  color: _canResend ? AppColors.primary : AppColors.textSecondary,
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        AppPrimaryButton(
                          text: isBn ? 'সাবস্ক্রিপশন নিশ্চিত করুন' : 'Confirm Subscription',
                          isLoading: _isLoading,
                          onPressed: _handleVerifyOtp,
                        ),
                      ],
                      const SizedBox(height: 12.0),
                      Center(
                        child: Text(
                          isBn ? pricing.vatSdText ?? '+ ভ্যাট, এসডি ও এসসি প্রযোজ্য' : '+ VAT, SD & SC applicable',
                          style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24.0),
            ],
          ),
        ),
      ),
    );
  }
}
