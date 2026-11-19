import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/family_providers.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import 'invite_family_screen.dart';

/// "I look after someone": enter the code they sent; they then approve the request.
class JoinCareScreen extends ConsumerStatefulWidget {
  const JoinCareScreen({super.key});

  @override
  ConsumerState<JoinCareScreen> createState() => _JoinCareScreenState();
}

class _JoinCareScreenState extends ConsumerState<JoinCareScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _joinedName;

  bool get _bn => ref.read(appSettingsProvider).language == 'bn';
  String _t(String bn, String en) => _bn ? bn : en;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final service = ref.read(familyServiceProvider);
    final uid = ref.read(userUidProvider);
    if (service == null || uid == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = ref.read(userProfileProvider);
      final name = await service.join(
        code: _code.text,
        myUid: uid,
        myName: profile.name.trim().isEmpty ? '?' : profile.name.trim(),
      );
      if (mounted) setState(() => _joinedName = name);
    } catch (e) {
      if (mounted) setState(() => _error = familyErrorText(e, _bn));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('আমি দেখাশোনা করি', 'I look after someone')),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          children: _joinedName != null
              ? [
                  const Icon(Icons.hourglass_top_rounded, size: 56, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    _t('$_joinedName-কে অনুরোধ পাঠানো হয়েছে। তিনি নিজের ফোনে "পরিবার" অংশে অনুমতি দিলে আপনি তাঁর ওষুধ দেখতে পাবেন।',
                        'Request sent to $_joinedName. Once they approve it in the Family tab on their phone, you will see their medicines.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  AppPrimaryButton(text: _t('ঠিক আছে', 'OK'), icon: Icons.check_rounded, onPressed: () => context.pop()),
                ]
              : [
                  Text(
                    _t('যাঁকে দেখাশোনা করেন, তাঁর ফোনে "পরিবার" > "পরিবারকে আমন্ত্রণ" চাপলে ৮ অক্ষরের একটি কোড আসবে। সেটি এখানে লিখুন।',
                        'Ask the person you look after to open Family > "Invite a family member" on their phone. Enter the 8-character code it shows.'),
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 \-]')), LengthLimitingTextInputFormatter(10)],
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 3),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(hintText: 'ABCD 2345', errorText: _error),
                    onSubmitted: (_) => _join(),
                  ),
                  const SizedBox(height: 20),
                  _busy
                      ? const Center(child: CircularProgressIndicator())
                      : AppPrimaryButton(text: _t('অনুরোধ পাঠান', 'Send request'), icon: Icons.send_rounded, onPressed: _join),
                ],
        ),
      ),
    );
  }
}
