import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/cloud_sync_provider.dart';
import '../../../core/providers/family_providers.dart';
import '../../../core/services/family_service.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/phone_actions.dart';
import '../../../shared/widgets/app_primary_button.dart';

/// "Invite a family member": shows a one-time code they enter on their own phone.
/// Their access starts only after I approve the request in the Family tab.
class InviteFamilyScreen extends ConsumerStatefulWidget {
  const InviteFamilyScreen({super.key});

  @override
  ConsumerState<InviteFamilyScreen> createState() => _InviteFamilyScreenState();
}

class _InviteFamilyScreenState extends ConsumerState<InviteFamilyScreen> {
  ({String code, DateTime expiresAt})? _invite;
  String? _error;

  bool get _bn => ref.read(appSettingsProvider).language == 'bn';
  String _t(String bn, String en) => _bn ? bn : en;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    // Family members read my medicines from my cloud backup, so it must be on.
    if (!ref.read(appSettingsProvider).cloudBackupEnabled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_t('শেয়ার করতে ব্যাকআপ লাগবে', 'Sharing needs your backup')),
          content: Text(_t(
            'পরিবারের সদস্য আপনার অ্যাকাউন্টের ব্যাকআপ থেকে আপনার ওষুধের তালিকা ও কোন ওষুধ খেয়েছেন তা দেখবেন। তাই ব্যাকআপ (Google Firebase-এ) চালু হবে। আপনি অনুমতি না দিলে কেউ কিছু দেখতে পারবে না, আর যেকোনো সময় কাউকে সরিয়ে দিতে পারবেন।',
            'Your family member sees your medicine list and which doses you took from the backup in your account, so backup (on Google Firebase) will be turned on. Nobody sees anything until you approve them, and you can remove anyone at any time.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_t('বাতিল', 'Cancel'))),
            ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(_t('চালু করুন', 'Turn on'))),
          ],
        ),
      );
      if (ok != true) {
        if (mounted) context.pop();
        return;
      }
      ref.read(appSettingsProvider.notifier).setCloudBackup(true);
      runCloudSync(ref);
    }
    final service = ref.read(familyServiceProvider);
    final uid = ref.read(userUidProvider);
    if (service == null || uid == null) {
      setState(() => _error = _t('এখন আমন্ত্রণ তৈরি করা যাচ্ছে না।', 'Cannot create an invite right now.'));
      return;
    }
    final profile = ref.read(userProfileProvider);
    try {
      final invite = await service.createInvite(myUid: uid, myName: profile.name.trim().isEmpty ? '?' : profile.name.trim());
      if (mounted) setState(() => _invite = invite);
    } catch (_) {
      if (mounted) {
        setState(() => _error = _t('আমন্ত্রণ তৈরি হয়নি। ইন্টারনেট চালু করে আবার চেষ্টা করুন।',
            'Could not create the invite. Connect to the internet and try again.'));
      }
    }
  }

  String _shareText(String code) => _t(
        'ওষুধসেবা অ্যাপে আমার ওষুধ দেখতে: অ্যাপ খুলে "পরিবার" > "আমি দেখাশোনা করি" চাপুন, তারপর এই কোড দিন: $code',
        'To see my medicines in OsudSheba: open the app, go to Family > "I look after someone" and enter this code: $code',
      );

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    final lang = _bn ? 'bn' : 'en';
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('পরিবারকে আমন্ত্রণ', 'Invite family')),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: [
            Text(
              _t('এই কোডটি আপনার ছেলে/মেয়ে বা যিনি দেখাশোনা করেন তাঁকে দিন। তিনি নিজের ফোনে ওষুধসেবা খুলে "পরিবার" > "আমি দেখাশোনা করি" চেপে কোডটি দেবেন। আপনি অনুমতি দিলে তবেই তিনি দেখতে পাবেন।',
                  'Give this code to your son, daughter, or whoever helps you. They open OsudSheba on their own phone, go to Family > "I look after someone" and enter it. They see nothing until you approve them.'),
              style: const TextStyle(fontSize: 15, height: 1.4, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 15))
            else if (invite == null)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    SelectableText(
                      '${invite.code.substring(0, 4)} ${invite.code.substring(4)}',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 4, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_t('মেয়াদ', 'Valid until')}: ${DateFormat('d MMM, h:mm a').format(invite.expiresAt)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                text: _t('এসএমএস দিয়ে পাঠান', 'Send by SMS'),
                icon: Icons.sms_rounded,
                onPressed: () => PhoneActions.shareBySms(context, _shareText(invite.code), lang: lang),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded),
                label: Text(_t('কোড কপি করুন', 'Copy code')),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: invite.code));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('কপি হয়েছে', 'Copied'))));
                },
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: () => context.pop(), child: Text(_t('হয়ে গেছে', 'Done'))),
            ],
          ],
        ),
      ),
    );
  }
}

/// Short, plain explanation of a [FamilyException] for the user.
String familyErrorText(Object e, bool bn) {
  final error = e is FamilyException ? e.error : null;
  switch (error) {
    case FamilyError.notFound:
      return bn ? 'কোডটি সঠিক নয়। আবার দেখে লিখুন।' : 'That code is not right. Please check it and try again.';
    case FamilyError.expired:
      return bn ? 'কোডের মেয়াদ শেষ। নতুন কোড চেয়ে নিন।' : 'This code has expired. Ask for a new one.';
    case FamilyError.ownCode:
      return bn ? 'এটি আপনার নিজের কোড।' : 'This is your own code.';
    case FamilyError.denied:
      return bn ? 'অনুমতি নেই।' : 'Not allowed.';
    case FamilyError.network:
    case null:
      return bn ? 'ইন্টারনেট চালু করে আবার চেষ্টা করুন।' : 'Connect to the internet and try again.';
  }
}
