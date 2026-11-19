import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/family_providers.dart';
import '../../../core/services/family_service.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/utils/care_view.dart';
import '../../../shared/widgets/confirm_dialog.dart';

/// The two halves of family sharing shown in the Family tab. Every account has both:
/// "People I look after" (I am a caregiver) and "My family" (who can see my medicines).
class FamilySections extends ConsumerWidget {
  const FamilySections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bn = ref.watch(appSettingsProvider).language == 'bn';
    String t(String b, String e) => bn ? b : e;
    final caring = ref.watch(caringProvider).valueOrNull ?? const <CaredPerson>[];
    final family = ref.watch(myFamilyProvider).valueOrNull ?? const <FamilyMember>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: t('যাঁদের দেখাশোনা করি', 'People I look after'),
          action: t('যোগ করুন', 'Add'),
          onAction: () => context.push('/family/join'),
        ),
        if (caring.isEmpty)
          _Empty(t('কারো কোড দিয়ে তাঁর ওষুধ দেখুন।', 'Enter someone\'s code to see their medicines.'))
        else
          for (final p in caring) _CaredTile(person: p, bn: bn),
        const SizedBox(height: 14),
        _Header(
          title: t('আমার পরিবার', 'My family'),
          action: t('আমন্ত্রণ', 'Invite'),
          onAction: () => context.push('/family/invite'),
        ),
        if (family.isEmpty)
          _Empty(t('পরিবারের কেউ আপনার ওষুধ দেখতে পারেন, আমন্ত্রণ পাঠান।', 'Invite family so they can see your medicines.'))
        else
          for (final m in family) _MemberTile(member: m, bn: bn),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.action, required this.onAction});
  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
        ),
        // Flexible: at large text sizes the button shrinks/wraps instead of overflowing.
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(action, style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: onAction,
            ),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.3));
}

Widget _card({required Widget child, VoidCallback? onTap}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.fromLTRB(12, 10, 8, 10), child: child),
        ),
      ),
    );

/// Someone I look after, with a live one-line summary of their day.
class _CaredTile extends ConsumerWidget {
  const _CaredTile({required this.person, required this.bn});
  final CaredPerson person;
  final bool bn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(careAccessProvider(person.uid)).valueOrNull;
    String summary;
    Color color = AppColors.textSecondary;
    if (access == 'pending') {
      summary = bn ? 'অনুমতির অপেক্ষায়' : 'Waiting for approval';
    } else if (access != 'active') {
      summary = bn ? 'অনুমতি নেই' : 'No access';
    } else {
      final doses = dosesForDay(
        medicines: ref.watch(careMedicinesProvider(person.uid)).valueOrNull ?? const [],
        logs: ref.watch(careLogsProvider(person.uid)).valueOrNull ?? const [],
        now: DateTime.now(),
      );
      final missed = doses.where((d) => d.state == DoseState.missed).length;
      final due = doses.where((d) => d.state == DoseState.dueNow).length;
      final taken = doses.where((d) => d.state == DoseState.taken).length;
      if (missed > 0) {
        summary = bn ? '$missedটি মিস হয়েছে' : '$missed missed today';
        color = AppColors.error;
      } else if (due > 0) {
        summary = bn ? '$dueটি এখন খাওয়ার সময়' : '$due due now';
        color = AppColors.warning;
      } else {
        summary = bn ? 'আজ খেয়েছেন $taken/${doses.length}' : 'Taken today $taken/${doses.length}';
        color = AppColors.success;
      }
    }
    return _card(
      onTap: () => context.push('/family/person', extra: person),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryLight,
            child: Icon(Icons.elderly_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                Text(summary, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ],
      ),
    );
  }
}

/// Someone who can see my medicines, or is asking to.
class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member, required this.bn});
  final FamilyMember member;
  final bool bn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String t(String b, String e) => bn ? b : e;
    final service = ref.read(familyServiceProvider);
    final uid = ref.read(userUidProvider);

    Future<void> remove() async {
      final ok = await showConfirmDialog(
        context,
        title: member.active ? t('${member.name}-কে সরাবেন?', 'Remove ${member.name}?') : t('অনুরোধ বাতিল করবেন?', 'Decline the request?'),
        message: t('তিনি আর আপনার ওষুধ দেখতে পারবেন না।', 'They will not be able to see your medicines.'),
        confirmLabel: member.active ? t('সরান', 'Remove') : t('বাতিল', 'Decline'),
        cancelLabel: t('না', 'No'),
        icon: Icons.person_remove_rounded,
      );
      if (ok && service != null && uid != null) await service.removeFamily(myUid: uid, caregiverUid: member.uid);
    }

    return _card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: member.active ? AppColors.primaryLight : AppColors.warning.withValues(alpha: 0.12),
            child: Icon(member.active ? Icons.visibility_rounded : Icons.person_add_alt_1_rounded,
                color: member.active ? AppColors.primary : AppColors.warning, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                Text(
                  member.active ? t('আপনার ওষুধ দেখতে পারেন', 'Can see your medicines') : t('দেখতে চাইছেন', 'Wants to see your medicines'),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (!member.active)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(0, 40)),
              onPressed: service == null || uid == null ? null : () => service.approve(myUid: uid, caregiverUid: member.uid),
              child: Text(t('অনুমতি দিন', 'Approve')),
            ),
          IconButton(
            tooltip: member.active ? t('সরান', 'Remove') : t('বাতিল', 'Decline'),
            icon: const Icon(Icons.close_rounded, color: AppColors.error),
            onPressed: remove,
          ),
        ],
      ),
    );
  }
}
