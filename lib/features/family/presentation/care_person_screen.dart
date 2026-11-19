import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/family_providers.dart';
import '../../../core/services/family_service.dart';
import '../../../core/services/phone_actions.dart';
import '../../../core/utils/caregiver_sms.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/utils/care_view.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'care_widgets.dart';
import 'invite_family_screen.dart';
import 'reminder_sheet.dart';

/// A caregiver's live view of someone they look after: what to take now, today's doses,
/// the last 7 days, their medicines, and "Send reminder".
class CarePersonScreen extends ConsumerStatefulWidget {
  const CarePersonScreen({super.key, required this.person});
  final CaredPerson person;

  @override
  ConsumerState<CarePersonScreen> createState() => _CarePersonScreenState();
}

class _CarePersonScreenState extends ConsumerState<CarePersonScreen> {
  Timer? _tick;
  late String? _phone = widget.person.phone;

  @override
  void initState() {
    super.initState();
    // "Due now" and "missed" depend on the clock, not only on new data.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool get _bn => ref.read(appSettingsProvider).language == 'bn';
  String _t(String bn, String en) => _bn ? bn : en;

  Future<void> _leave() async {
    final ok = await showConfirmDialog(
      context,
      title: _t('দেখাশোনা বন্ধ করবেন?', 'Stop looking after ${widget.person.name}?'),
      message: _t('আপনি আর ${widget.person.name}-এর ওষুধ দেখতে পাবেন না।', 'You will no longer see their medicines.'),
      confirmLabel: _t('হ্যাঁ, বন্ধ করুন', 'Yes, stop'),
      cancelLabel: _t('না', 'No'),
      icon: Icons.person_remove_rounded,
    );
    if (!ok) return;
    final uid = ref.read(userUidProvider);
    if (uid != null) await ref.read(familyServiceProvider)?.leave(patientUid: widget.person.uid, myUid: uid);
    if (mounted) context.pop();
  }

  Future<void> _sendReminder() async {
    final presets = [
      _t('ওষুধ খাওয়ার সময় হয়েছে, খেয়ে নিন।', 'It is time for your medicine. Please take it.'),
      _t('ওষুধ খেয়েছেন? অ্যাপে "খেয়েছি" চাপুন।', 'Did you take your medicine? Tap "I took it" in the app.'),
    ];
    final message = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in presets)
              ListTile(leading: const Icon(Icons.chat_bubble_outline_rounded), title: Text(p), onTap: () => Navigator.of(ctx).pop(p)),
          ],
        ),
      ),
    );
    if (message == null || !mounted) return;
    final uid = ref.read(userUidProvider);
    final service = ref.read(familyServiceProvider);
    if (uid == null || service == null) return;
    final me = ref.read(userProfileProvider).name.trim();

    final method = await showReminderMethodSheet(context, bn: _bn, phone: _phone);
    if (method == null || !mounted) return;
    if (method != ReminderMethod.notification) {
      // SMS goes from the caregiver's own phone and SIM: the messaging app opens with the
      // number and text filled in, and they press Send there.
      var phone = _phone;
      if (phone == null || method == ReminderMethod.changeNumber) {
        phone = await askMobileNumber(context, bn: _bn, name: widget.person.name, current: phone);
        if (phone == null || !mounted) return;
        setState(() => _phone = phone);
        try {
          await service.savePatientPhone(myUid: uid, patientUid: widget.person.uid, phone: phone);
        } catch (_) {
          // Not saved for next time; the SMS can still be sent now.
        }
        if (!mounted) return;
      }
      await PhoneActions.sms(context, phone, caregiverSmsBody(message: message, fromName: me, bn: _bn),
          lang: _bn ? 'bn' : 'en');
      return;
    }
    String text;
    try {
      final pushed = await service.sendReminder(
        patientUid: widget.person.uid,
        myUid: uid,
        myName: me.isEmpty ? '?' : me,
        message: message,
      );
      text = pushed
          ? _t('রিমাইন্ডার পাঠানো হয়েছে।', 'Reminder sent.')
          : _t('রিমাইন্ডার রাখা হয়েছে; অ্যাপ খুললে দেখবেন।', 'Reminder saved; they will see it when they open the app.');
    } catch (e) {
      text = familyErrorText(e, _bn);
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appSettingsProvider);
    final person = widget.person;
    final access = ref.watch(careAccessProvider(person.uid));

    return Scaffold(
      appBar: AppBar(
        title: Text(person.name),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(tooltip: _t('দেখাশোনা বন্ধ', 'Stop looking after'), icon: const Icon(Icons.person_remove_rounded), onPressed: _leave),
        ],
      ),
      body: SafeArea(
        child: access.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _message(_t('তথ্য আনা যায়নি। ইন্টারনেট দেখুন।', 'Could not load. Check the internet.')),
          data: (status) => switch (status) {
            'active' => _active(),
            'pending' => _message(_t('${person.name} এখনো অনুমতি দেননি। তাঁর ফোনে "পরিবার" অংশে অনুমতি দিতে বলুন।',
                'Waiting for ${person.name} to approve you. Ask them to approve it in the Family tab on their phone.')),
            _ => _message(_t('${person.name} আপনার দেখার অনুমতি সরিয়ে দিয়েছেন।', '${person.name} removed your access.'),
                action: AppPrimaryButton(text: _t('তালিকা থেকে সরান', 'Remove from my list'), onPressed: _leave)),
          },
        ),
      ),
    );
  }

  Widget _message(String text, {Widget? action}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.4)),
            if (action != null) ...[const SizedBox(height: 20), action],
          ]),
        ),
      );

  Widget _active() {
    final bn = _bn;
    final meds = ref.watch(careMedicinesProvider(widget.person.uid)).valueOrNull ?? const [];
    final logs = ref.watch(careLogsProvider(widget.person.uid)).valueOrNull ?? const [];
    final now = DateTime.now();
    final today = dosesForDay(medicines: meds, logs: logs, now: now);
    final active = meds.where((m) => m.status == 'active').toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            children: [
              NowCard(doses: today, bn: bn),
              CareSection(
                title: _t('আজকের ডোজ', 'Today'),
                child: today.isEmpty
                    ? Text(_t('আজ কোনো ডোজ নেই।', 'No doses today.'), style: const TextStyle(color: AppColors.textSecondary))
                    : Column(children: [for (final d in today) DoseRow(dose: d, bn: bn)]),
              ),
              CareSection(
                title: _t('গত ৭ দিন (খাওয়ার হার %)', 'Last 7 days (% taken)'),
                child: WeekStrip(values: dailyAdherence(logs: logs, now: now), now: now, bn: bn),
              ),
              CareSection(
                title: _t('ওষুধের তালিকা', 'Medicines'),
                child: active.isEmpty
                    ? Text(_t('কোনো ওষুধ নেই।', 'No medicines.'), style: const TextStyle(color: AppColors.textSecondary))
                    : Column(children: [for (final m in active) MedicineLine(medicine: m, bn: bn)]),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: AppPrimaryButton(
            text: _t('রিমাইন্ডার পাঠান', 'Send reminder'),
            icon: Icons.notifications_active_rounded,
            onPressed: _sendReminder,
          ),
        ),
      ],
    );
  }
}
