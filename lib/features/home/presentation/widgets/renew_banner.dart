import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/subscription.dart';
import '../../../../core/providers/subscription_provider.dart';
import '../../../../core/services/mock_data_service.dart';

/// Home, when the server says the subscription is not active (lapsed, cancelled, or the
/// charge failed): reminders keep working, and one tap renews. Hidden while subscribed,
/// while a charge is still pending, and when the status could not be checked (offline).
class RenewBanner extends ConsumerWidget {
  const RenewBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Subscription? sub;
    try {
      sub = ref.watch(subscriptionProvider).valueOrNull;
    } catch (_) {
      sub = null; // status unavailable (no sign-in service): show nothing rather than break Home
    }
    if (sub == null || sub.isEntitled || sub.isPending || sub.state == SubscriptionState.error) {
      return const SizedBox.shrink();
    }
    final bn = ref.watch(appSettingsProvider).language == 'bn';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: const Color(0xFFFFF7ED),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.warning),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                bn
                    ? 'সাবস্ক্রিপশন বন্ধ। রিমাইন্ডার চলবে; ওষুধ যোগ বা বদলাতে আবার চালু করুন।'
                    : 'Subscription off. Reminders keep working; renew to add or change medicines.',
                style: const TextStyle(fontSize: 14.5, height: 1.3, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(
              onPressed: () => context.push('/subscription'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.warning,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 44),
              ),
              child: Text(bn ? 'চালু করুন' : 'Renew', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }
}
