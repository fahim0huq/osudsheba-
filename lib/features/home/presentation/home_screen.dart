import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/utils/home_schedule.dart';
import '../../../core/utils/stock.dart';
import '../../../core/utils/time_label.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../family/presentation/nudge_banner.dart';
import 'dose_recorder.dart';
import 'widgets/next_dose_card.dart';
import 'widgets/next_dose_visuals.dart';
import 'widgets/progress_ring_card.dart';
import 'widgets/renew_banner.dart';

/// Home: today's progress ring, the animated next-dose card and one button that opens
/// Today's medicines (where medicines are listed, added, changed, paused or deleted).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// A dose whose time came less than this long ago is "due"; after that it is "late".
  static const dueWindow = Duration(minutes: 30);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).language;
    final bn = lang == 'bn';
    final medicines = ref.watch(medicinesProvider);
    final logs = ref.watch(doseLogsProvider);
    // Ticks every minute, so the card moves on and the countdown updates as time passes.
    final now = ref.watch(minuteClockProvider).valueOrNull ?? DateTime.now();

    final doses = todayDoses(medicines: medicines, logs: logs, now: now);
    final taken = doses.where((d) => d.state == DoseState.taken).length;
    final left = doses.where((d) => d.state == DoseState.pending || d.state == DoseState.missed).length;

    // The card shows the earliest dose not recorded yet: one whose time has passed first,
    // otherwise the next one later today, otherwise tomorrow's first ("all done").
    final overdue = findOverdueToday(medicines: medicines, logs: logs, now: now);
    final slot = overdue.isNotEmpty ? overdue.first : findNextDose(medicines: medicines, logs: logs, now: now);
    var mood = DoseMood.upcoming;
    var wait = Duration.zero;
    if (slot != null) {
      final since = now.difference(slot.scheduledAt);
      if (slot.isTomorrow) {
        mood = DoseMood.done;
      } else if (since.isNegative) {
        wait = -since;
      } else {
        mood = since <= dueWindow ? DoseMood.due : DoseMood.late;
        wait = since;
      }
    }

    final patientName = ref.watch(patientProfileProvider).name;
    final greeting = bn ? 'আসসালামু আলাইকুম' : 'Assalamu Alaikum';

    return Scaffold(
      appBar: AppBar(
        title: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: patientName.isEmpty ? greeting : '$greeting, ',
              style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            ),
            if (patientName.isNotEmpty) TextSpan(text: patientName),
          ]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: 24),
            tooltip: bn ? 'সেটিংস' : 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NudgeBanner(), // reminders sent by family
            const RenewBanner(), // subscription off: reminders still work
            if (medicines.isEmpty)
              EmptyState(
                title: bn ? 'ওষুধের তালিকা খালি' : 'No Medicines Scheduled',
                message: bn
                    ? 'আপনার কোনো ওষুধ যোগ করা নেই। নিজে ওষুধ যোগ করুন অথবা প্রেসক্রিপশন স্ক্যান করুন!'
                    : 'You haven\'t added any medicines yet. Add manually or scan a prescription!',
                icon: Icons.medical_services_outlined,
                primaryActionLabel: bn ? 'নিজে ওষুধ যোগ করুন' : 'Add Manually',
                onPrimaryAction: () => context.go('/add-medicine'),
                secondaryActionLabel: bn ? 'প্রেসক্রিপশন স্ক্যান করুন' : 'Scan Prescription',
                onSecondaryAction: () => context.go('/upload-prescription'),
              )
            else ...[
              ProgressRingCard(taken: taken, total: doses.length, left: left, language: lang),
              const SizedBox(height: 14),
              NextDoseCard(
                slot: slot,
                mood: mood,
                wait: wait,
                language: lang,
                onTaken: () {
                  if (slot != null && !slot.isTomorrow) recordDoses(context, ref, slot.medicines, slot.time, 'taken');
                },
                onSkip: () {
                  if (slot != null && !slot.isTomorrow) confirmSkipDoses(context, ref, slot.medicines, slot.time);
                },
                onTap: () {
                  if (slot == null || slot.isTomorrow) return;
                  final med = slot.medicines.first;
                  ref.read(selectedMedicineProvider.notifier).state = med;
                  context.push('/dose-action', extra: {'medicine': med, 'scheduledTime': slot.time});
                },
              ),
              const SizedBox(height: 14),
              _TodaysMedicinesButton(count: doses.length, language: lang),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens Today's medicines: the full list, with add, edit, pause and delete.
class _TodaysMedicinesButton extends ConsumerWidget {
  final int count;
  final String language;
  const _TodaysMedicinesButton({required this.count, required this.language});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bn = language == 'bn';
    // Medicines whose counted stock is running low: shown in place of the subtitle, so the
    // button never grows.
    final logs = ref.watch(doseLogsProvider);
    final days = ref.watch(appSettingsProvider.select((s) => s.refillAlertDays));
    final now = DateTime.now();
    final toBuy = ref
        .watch(medicinesProvider)
        .where((m) => stockStatus(m, logs, now, alertDays: days)?.needsBuying ?? false)
        .length;
    final title = bn ? 'আজকের সব ওষুধ' : "Today's medicines";
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.primary, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(toBuy > 0 ? '/medicines?tab=all' : '/medicines'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.format_list_bulleted_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$title (${localDigits(count, language)})',
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                if (toBuy > 0)
                  Row(children: [
                    const Icon(Icons.shopping_bag_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        bn ? '${localDigits(toBuy, language)}টি ওষুধ কিনতে হবে' : '$toBuy to buy soon',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.warning),
                      ),
                    ),
                  ])
                else
                  Text(bn ? 'দেখুন, যোগ করুন, বদলান' : 'See, add and change',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 30),
          ]),
        ),
      ),
    );
  }
}
