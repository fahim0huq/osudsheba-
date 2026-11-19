import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/phone_actions.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/app_secondary_button.dart';

/// Add a family member who helps with medicines.
///
/// What this screen really does (and says it does):
///  * saves the person's number on this phone as the family / emergency contact, used by
///    the "Call family" button on the dose screen;
///  * optionally opens the phone's SMS app with a ready-written message the user can send.
///
/// The app has no server-side caregiver accounts yet, so it does not claim to send
/// invitations or remote missed-dose alerts. (The previous version showed
/// "Invitation link sent successfully via SMS!" without sending anything.)
class CaregiverInviteScreen extends ConsumerStatefulWidget {
  const CaregiverInviteScreen({super.key});

  @override
  ConsumerState<CaregiverInviteScreen> createState() => _CaregiverInviteScreenState();
}

class _CaregiverInviteScreenState extends ConsumerState<CaregiverInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationshipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    if (profile.emergencyContact.isNotEmpty) {
      _phoneController.text = profile.emergencyContact;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value, String lang) {
    final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final local = digits.startsWith('880') ? '0${digits.substring(3)}' : digits;
    if (local.isEmpty) {
      return lang == 'bn' ? 'মোবাইল নম্বর লিখুন' : 'Please enter a mobile number';
    }
    if (!RegExp(r'^01[3-9]\d{8}$').hasMatch(local)) {
      return lang == 'bn'
          ? '১১ সংখ্যার মোবাইল নম্বর লিখুন, যেমন 01712345678'
          : 'Enter an 11-digit mobile number, e.g. 01712345678';
    }
    return null;
  }

  String _normalizedPhone() {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.startsWith('880') ? '0${digits.substring(3)}' : digits;
  }

  void _save(String lang) {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final notifier = ref.read(userProfileProvider.notifier);
    final current = ref.read(userProfileProvider);
    notifier.updateProfile(current.copyWith(emergencyContact: _normalizedPhone()));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang == 'bn'
            ? 'পরিবারের নম্বর এই ফোনে সংরক্ষণ করা হয়েছে।'
            : 'Family contact saved on this phone.'),
        backgroundColor: AppColors.success,
      ),
    );
    if (context.canPop()) context.pop();
  }

  Future<void> _sendSms(String lang) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final myName = ref.read(userProfileProvider).name;
    final name = _nameController.text.trim();
    final message = lang == 'bn'
        ? 'প্রিয় ${name.isEmpty ? '' : name}, আমি ওষুধ খাওয়ার সময় মনে রাখতে "ওষুধসেবা" অ্যাপ ব্যবহার করছি। আমি আপনাকে আমার পারিবারিক যোগাযোগ হিসেবে যোগ করেছি, প্রয়োজনে আপনাকে কল করতে পারি। ${myName.isEmpty ? '' : '- $myName'}'
        : 'Hi ${name.isEmpty ? 'there' : name}, I am using the OsudSheba app to remember my medicines. I have added you as my family contact so I can call you if I need help. ${myName.isEmpty ? '' : '- $myName'}';
    await PhoneActions.sms(context, _normalizedPhone(), message.trim(), lang: lang);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).language;
    final title = lang == 'bn' ? 'পরিবারের সদস্য যোগ করুন' : 'Add a family member';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  lang == 'bn'
                      ? 'যিনি আপনার ওষুধের ব্যাপারে সাহায্য করেন, তার নম্বর এখানে রাখুন। ওষুধের স্ক্রিনে "পরিবারকে কল" চাপলে এই নম্বরে কল করা যাবে।'
                      : 'Save the number of someone who helps you with your medicines. The "Call family" button on the dose screen will call this number.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 17.0, height: 1.4),
                ),
                const SizedBox(height: 24.0),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: lang == 'bn' ? 'নাম (ঐচ্ছিক)' : 'Name (optional)',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: InputDecoration(
                    labelText: lang == 'bn' ? 'মোবাইল নম্বর' : 'Mobile number',
                    hintText: '01XXXXXXXXX',
                    prefixIcon: const Icon(Icons.phone_rounded),
                  ),
                  validator: (v) => _validatePhone(v, lang),
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  controller: _relationshipController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: lang == 'bn' ? 'সম্পর্ক (ঐচ্ছিক), যেমন মেয়ে' : 'Relationship (optional), e.g. daughter',
                    prefixIcon: const Icon(Icons.family_restroom_rounded),
                  ),
                ),
                const SizedBox(height: 20.0),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.primaryDark),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          lang == 'bn'
                              ? 'ওষুধ মিস হলে এই অ্যাপ এখনো পরিবারের সদস্যকে স্বয়ংক্রিয়ভাবে জানায় না। চাইলে নিচের বোতাম দিয়ে নিজের ফোন থেকে একটি মেসেজ পাঠাতে পারেন।'
                              : 'The app does not yet alert family members automatically when a dose is missed. You can send them a message from your own phone with the button below.',
                          style: const TextStyle(fontSize: 16.0, height: 1.4, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28.0),
                AppPrimaryButton(
                  text: lang == 'bn' ? 'নম্বর সংরক্ষণ করুন' : 'Save contact',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () => _save(lang),
                ),
                const SizedBox(height: 12.0),
                AppSecondaryButton(
                  text: lang == 'bn' ? 'মেসেজ অ্যাপে লিখে পাঠান' : 'Write them a text message',
                  icon: Icons.sms_outlined,
                  onPressed: () => _sendSms(lang),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
