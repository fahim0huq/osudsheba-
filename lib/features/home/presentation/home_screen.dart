import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/utils/home_schedule.dart';
import '../../../core/utils/schedule_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../family/presentation/nudge_banner.dart';
import 'widgets/adherence_summary_card.dart';
import 'widgets/next_dose_card.dart';
import 'widgets/overdue_doses_card.dart';
import 'widgets/today_medicine_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).language;
    final bn = lang == 'bn';
    final medicines = ref.watch(medicinesProvider);
    final logs = ref.watch(doseLogsProvider);
    // Ticks every minute, so the next dose and overdue list move on as time passes.
    final now = ref.watch(minuteClockProvider).valueOrNull ?? DateTime.now();

    final counts = todayDoseCounts(medicines: medicines, logs: logs, now: now);
    final next = findNextDose(medicines: medicines, logs: logs, now: now);
    final overdue = findOverdueToday(medicines: medicines, logs: logs, now: now);

    /// Logs [status] for every medicine in [meds] at [slot], then offers Undo.
    void recordDoses(List<Medicine> meds, String slot, String status) {
      final notifier = ref.read(doseLogsProvider.notifier);
      final changes = <(DoseLog, DoseLog?)>[];
      for (final med in meds) {
        final log = DoseLog(
          id: const Uuid().v4(),
          medicineId: med.id,
          medicineName: '${med.name} ${med.strength}'.trim(),
          scheduledTime: slot,
          status: status,
          actualTime: DateTime.now(),
        );
        final previous = notifier.findSameSlotLog(log);
        final stored = notifier.addLogReturning(log);
        changes.add((stored, previous));
      }
      final taken = status == 'taken';
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(taken
            ? (bn ? 'খাওয়া হয়েছে বলে রেকর্ড করা হলো' : 'Recorded as taken')
            : (bn ? 'বাদ দেওয়া হয়েছে বলে রেকর্ড করা হলো' : 'Recorded as skipped')),
        backgroundColor: taken ? AppColors.success : AppColors.textSecondary,
        action: SnackBarAction(
          label: bn ? 'ফিরিয়ে নিন' : 'UNDO',
          textColor: Colors.white,
          onPressed: () {
            for (final (added, previous) in changes) {
              notifier.undoLog(added, previous);
            }
          },
        ),
      ));
    }

    Future<void> confirmSkip(List<Medicine> meds, String slot) async {
      final ok = await showConfirmDialog(
        context,
        title: bn ? 'এই ডোজ বাদ দেবেন?' : 'Skip this dose?',
        message: bn
            ? 'ডাক্তারের পরামর্শ ছাড়া ওষুধ বাদ দেবেন না। তবুও বাদ দিলে এটি রেকর্ড হবে।'
            : 'Do not skip medicines unless your doctor told you to. If you skip, it will be recorded.',
        confirmLabel: bn ? 'হ্যাঁ, বাদ দিন' : 'Yes, skip it',
        cancelLabel: bn ? 'না, ফিরে যান' : 'No, go back',
        icon: Icons.skip_next_rounded,
      );
      if (ok && context.mounted) recordDoses(meds, slot, 'skipped');
    }

    final patientName = ref.watch(patientProfileProvider).name;
    final greeting = bn ? 'আসসালামু আলাইকুম' : 'Assalamu Alaikum';

    return Scaffold(
      appBar: AppBar(
        // The greeting is the title, so the cards below get the space.
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NudgeBanner(), // reminders sent by family
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
              AdherenceSummaryCard(takenCount: counts.taken, totalCount: counts.total, language: lang),
              const SizedBox(height: 8),
              NextDoseCard(
                slot: next,
                language: lang,
                onTaken: () {
                  if (next != null && !next.isTomorrow) recordDoses(next.medicines, next.time, 'taken');
                },
                onSkip: () {
                  if (next != null && !next.isTomorrow) confirmSkip(next.medicines, next.time);
                },
                onTap: () {
                  if (next == null) return;
                  final med = next.medicines.first;
                  ref.read(selectedMedicineProvider.notifier).state = med;
                  context.push('/dose-action', extra: {'medicine': med, 'scheduledTime': next.time});
                },
              ),
              if (overdue.isNotEmpty) ...[
                const SizedBox(height: 8),
                OverdueDosesCard(
                  slots: overdue,
                  lang: lang,
                  onTaken: (s) => recordDoses(s.medicines, s.time, 'taken'),
                  onSkip: (s) => confirmSkip(s.medicines, s.time),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.get('todays_medicines', lang),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/medicines'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      bn ? 'সব দেখুন' : 'See All',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              for (final med in medicines)
                TodayMedicineTile(
                  medicine: med,
                  status: todayStatusFor(med, logs, now),
                  language: lang,
                  onTap: () {
                    ref.read(selectedMedicineProvider.notifier).state = med;
                    context.push('/medicine-detail', extra: med);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}
