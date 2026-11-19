import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/family_providers.dart';
import '../../../core/services/mock_data_service.dart';

/// Home: reminders a family member sent ("Rahim: please take your 8 PM medicine").
/// While the app is open they appear here (the push notification covers a closed app).
class NudgeBanner extends ConsumerWidget {
  const NudgeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nudges = ref.watch(nudgesProvider).valueOrNull ?? const [];
    if (nudges.isEmpty) return const SizedBox.shrink();
    final bn = ref.watch(appSettingsProvider).language == 'bn';
    final uid = ref.watch(userUidProvider);

    return Column(
      children: [
        for (final n in nudges)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.fromName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark)),
                      Text(n.message, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: uid == null ? null : () => ref.read(familyServiceProvider)?.dismissNudge(myUid: uid, id: n.id),
                  child: Text(bn ? 'ঠিক আছে' : 'OK', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
