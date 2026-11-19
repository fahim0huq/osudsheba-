import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/schedule_utils.dart';
import '../../../core/utils/time_utils.dart';
import 'widgets/medicine_detail_parts.dart';

class MedicineDetailScreen extends ConsumerStatefulWidget {
  final Medicine? medicine;

  const MedicineDetailScreen({super.key, this.medicine});

  @override
  ConsumerState<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends ConsumerState<MedicineDetailScreen> {
  String? _selectedTime;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    // Always show the latest saved version of the chosen medicine (the route argument is a
    // snapshot and went stale after editing). Never fall back to a different medicine.
    final medList = ref.watch(medicinesProvider);
    final requested = widget.medicine ?? ref.watch(selectedMedicineProvider);
    final matches = requested == null ? const <Medicine>[] : medList.where((m) => m.id == requested.id).toList();
    final Medicine? currentMed = matches.isEmpty ? null : matches.first;

    if (currentMed == null) {
      final errorTitle = lang == 'bn' ? 'ওষুধ পাওয়া যায়নি' : 'Medicine Not Found';
      final errorMessage = lang == 'bn'
          ? 'দুঃখিত, এই ওষুধের কোনো তথ্য পাওয়া যায়নি।'
          : 'Sorry, we couldn\'t find details for this medicine.';
      final backText = lang == 'bn' ? 'ওষুধের তালিকায় ফিরুন' : 'Back to Medicines';
      return Scaffold(
        appBar: AppBar(
          title: Text(errorTitle),
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              ),
              const SizedBox(height: 16.0),
              Text(
                errorTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8.0),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14.5),
                ),
              ),
              const SizedBox(height: 24.0),
              ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(backText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final logs = ref.watch(doseLogsProvider);
    final now = ref.watch(minuteClockProvider).valueOrNull ?? DateTime.now();
    final bn = lang == 'bn';

    // Default to the first dose today that has not been taken or skipped yet.
    String? defaultTime;
    for (final time in currentMed.times) {
      if (!hasDoseLog(logs, currentMed.id, time, now)) {
        defaultTime = time;
        break;
      }
    }
    defaultTime ??= currentMed.times.isEmpty ? null : currentMed.times.first;
    final activeTime = currentMed.times.contains(_selectedTime) ? _selectedTime : defaultTime;

    // This medicine over the last 7 days: taken (on time or late) out of all recorded outcomes.
    final weekStart = dateOnly(now).subtract(const Duration(days: 6));
    final weekLogs = logs.where(
      (l) => l.medicineId == currentMed.id && l.actualTime != null && !l.actualTime!.isBefore(weekStart),
    );
    final weekTaken = weekLogs.where((l) => l.status == 'taken' || l.status == 'late').length;
    final weekRecorded = weekTaken + weekLogs.where((l) => l.status == 'skipped' || l.status == 'missed').length;

    // Today's record for the selected time, if any. Once it is taken, the buttons are
    // replaced by a "Taken at ..." banner so the same dose is not recorded twice.
    DoseLog? slotLog;
    for (final l in logs) {
      if (activeTime != null &&
          l.medicineId == currentMed.id &&
          sameTimeOfDay(l.scheduledTime, activeTime) &&
          l.actualTime != null &&
          isSameDay(l.actualTime!, now)) {
        slotLog = l;
        break;
      }
    }
    final takenLog = (slotLog != null && (slotLog.status == 'taken' || slotLog.status == 'late')) ? slotLog : null;
    final notifier = ref.read(doseLogsProvider.notifier);

    void record(String status, String message, Color color) {
      final slot = activeTime;
      if (slot == null) return;
      final log = DoseLog(
        id: const Uuid().v4(),
        medicineId: currentMed.id,
        medicineName: '${currentMed.name} ${currentMed.strength}'.trim(),
        scheduledTime: slot,
        status: status,
        actualTime: DateTime.now(),
      );
      final previous = notifier.findSameSlotLog(log);
      final stored = notifier.addLogReturning(log);
      // "Snooze" used to only write a log; it now really reminds again in 10 minutes.
      if (status == 'snoozed') NotificationService.instance.scheduleSnooze(currentMed, slot, 10);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: color,
            action: status == 'snoozed'
                ? null
                : SnackBarAction(
                    label: bn ? 'ফিরিয়ে নিন' : 'UNDO',
                    textColor: Colors.white,
                    onPressed: () => notifier.undoLog(stored, previous),
                  ),
          ),
        );
    }

    const buttonText = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);
    return Scaffold(
      appBar: AppBar(
        title: Text(bn ? 'ওষুধের বিস্তারিত' : 'Medicine Details'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.textSecondary),
            tooltip: bn ? 'সম্পাদনা' : 'Edit',
            onPressed: () {
              ref.read(selectedMedicineProvider.notifier).state = currentMed;
              context.push('/edit-medicine', extra: currentMed);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            tooltip: bn ? 'মুছুন' : 'Delete',
            onPressed: () => _showDeleteConfirmation(context, ref, currentMed, lang),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MedicineDetailHeader(medicine: currentMed, status: todayStatusFor(currentMed, logs, now), bn: bn),
            const SizedBox(height: 8),
            MedicineDetailFacts(medicine: currentMed, bn: bn),
            MedicineWeekSummary(taken: weekTaken, recorded: weekRecorded, bn: bn),
            const SizedBox(height: 14),
            if (currentMed.times.length > 1) ...[
              Text(
                bn ? 'কোন সময়ের ডোজ?' : 'Which dose?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final time in currentMed.times)
                    ChoiceChip(
                      label: Text(
                        time,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: activeTime == time ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      selected: activeTime == time,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.grey.shade100,
                      checkmarkColor: Colors.white,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedTime = time);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (takenLog != null)
              TakenDoseBanner(
                log: takenLog,
                bn: bn,
                onUndo: () {
                  notifier.undoLog(takenLog, null);
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(bn ? 'খাওয়ার রেকর্ড মুছে দেওয়া হয়েছে' : 'Taken record removed'),
                        backgroundColor: AppColors.textSecondary,
                      ),
                    );
                },
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          record('skipped', bn ? 'ডোজ বাদ দেওয়া হয়েছে' : 'Dose skipped', AppColors.textSecondary),
                      icon: const Icon(Icons.block_rounded, size: 20),
                      label: Text(bn ? 'বাদ দিন' : 'Skip'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        minimumSize: const Size(0, 48),
                        textStyle: buttonText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => record(
                        'snoozed',
                        bn ? '১০ মিনিট পরে আবার মনে করিয়ে দেবে' : 'Will remind you again in 10 minutes',
                        AppColors.warning,
                      ),
                      icon: const Icon(Icons.snooze_rounded, size: 20),
                      label: Text(bn ? '১০ মিনিট পরে' : 'Snooze 10 min'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade200),
                        minimumSize: const Size(0, 48),
                        textStyle: buttonText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () =>
                    record('taken', bn ? 'খাওয়া হয়েছে বলে রেকর্ড করা হলো' : 'Recorded as taken', AppColors.success),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
                label: Text(
                  activeTime == null
                      ? (bn ? 'খেয়েছি' : 'Mark as taken')
                      : (bn ? '$activeTime এর ডোজ খেয়েছি' : 'Mark $activeTime as taken'),
                  textAlign: TextAlign.center,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Medicine medicine, String lang) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(lang == 'bn' ? 'ওষুধ মুছুন' : 'Delete Medicine'),
          content: Text(
            lang == 'bn'
                ? 'আপনি কি নিশ্চিত যে আপনি "${medicine.name}" ওষুধটি তালিকা থেকে মুছে ফেলতে চান?'
                : 'Are you sure you want to delete "${medicine.name}"? This cannot be undone.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(lang == 'bn' ? 'বাতিল' : 'Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // dismiss dialog
                ref.read(medicinesProvider.notifier).deleteMedicine(medicine.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(lang == 'bn' ? 'ওষুধটি মুছে ফেলা হয়েছে' : 'Medicine deleted successfully'),
                    backgroundColor: AppColors.error,
                  ),
                );
                context.go('/home'); // go back to dashboard
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: Text(lang == 'bn' ? 'মুছে ফেলুন' : 'Delete'),
            ),
          ],
        );
      },
    );
  }
}
