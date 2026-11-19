import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/phone_actions.dart';
import '../../../core/utils/time_utils.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../core/utils/dose_text.dart';

class DoseActionScreen extends ConsumerWidget {
  final Medicine? medicine;
  final String scheduledTime;

  const DoseActionScreen({
    super.key,
    this.medicine,
    required this.scheduledTime,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final patientProfile = ref.watch(patientProfileProvider);
    final medList = ref.watch(medicinesProvider);

    // Find all active medicines for this scheduled time
    final List<Medicine> targetMedicines = [];
    if (medicine != null) {
      targetMedicines.add(medicine!);
    } else {
      final matches = medList
          .where((m) => m.status == 'active' && m.times.any((t) => sameTimeOfDay(t, scheduledTime)))
          .toList();
      if (matches.isNotEmpty) {
        targetMedicines.addAll(matches);
      } else {
        final selected = ref.watch(selectedMedicineProvider);
        if (selected != null) {
          targetMedicines.add(selected);
        }
        // Never fall back to an arbitrary medicine: logging a dose against the wrong
        // medicine would corrupt the patient's record.
      }
    }

    if (targetMedicines.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(lang == 'bn' ? 'ওষুধ খাওয়ার অ্যাকশন' : 'Dose Action')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              lang == 'bn'
                  ? 'এই সময়ের কোনো ওষুধ পাওয়া যায়নি।'
                  : 'No medicine is scheduled for this time.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18.0),
            ),
          ),
        ),
      );
    }

    final title = lang == 'bn' ? 'ওষুধ সেবন' : 'Dose Action';

    final slot = normalizeTimeString(scheduledTime) ?? scheduledTime;

    void onTakenAll() {
      NotificationService.instance.dismissTimeSlot(slot);
      for (final med in targetMedicines) {
        ref.read(doseLogsProvider.notifier).addLog(
              DoseLog(
                id: const Uuid().v4(),
                medicineId: med.id,
                medicineName: '${med.name} ${med.strength}'.trim(),
                scheduledTime: scheduledTime,
                status: 'taken',
                actualTime: DateTime.now(),
              ),
            );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang == 'bn' ? 'ওষুধ খাওয়া সম্পন্ন হয়েছে' : 'Dose marked as Taken!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/home');
    }

    Future<void> onSnoozeAll() async {
      await NotificationService.instance.dismissTimeSlot(slot);
      // Actually set the 10-minute reminder (previously this only showed a message).
      await NotificationService.instance.scheduleSnoozeForTimeGroup(slot, targetMedicines, 10);
      if (!context.mounted) return;
      for (final med in targetMedicines) {
        ref.read(doseLogsProvider.notifier).addLog(
              DoseLog(
                id: const Uuid().v4(),
                medicineId: med.id,
                medicineName: '${med.name} ${med.strength}'.trim(),
                scheduledTime: scheduledTime,
                status: 'snoozed',
                actualTime: DateTime.now(),
              ),
            );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang == 'bn' ? '১০ মিনিটের জন্য রিমাইন্ডার থামানো হয়েছে' : 'Snoozed for 10 minutes!'),
          backgroundColor: AppColors.warning,
        ),
      );
      context.go('/home');
    }

    Future<void> onSkipAll() async {
      final confirmed = await showConfirmDialog(
        context,
        title: lang == 'bn' ? 'এই ডোজ বাদ দেবেন?' : 'Skip this dose?',
        message: lang == 'bn'
            ? 'এই ডোজটি "বাদ দেওয়া হয়েছে" হিসেবে রেকর্ড হবে এবং আজ এই সময়ের জন্য আর অ্যালার্ম বাজবে না। ডাক্তারের পরামর্শ ছাড়া ওষুধ বাদ দেবেন না।'
            : 'This dose will be recorded as skipped and the alarm will not ring again for this time today. Do not skip medicines unless your doctor told you to.',
        confirmLabel: lang == 'bn' ? 'হ্যাঁ, বাদ দিন' : 'Yes, skip it',
        cancelLabel: lang == 'bn' ? 'না, ফিরে যান' : 'No, go back',
        icon: Icons.skip_next_rounded,
      );
      if (!confirmed) return;
      await NotificationService.instance.dismissTimeSlot(slot);
      if (!context.mounted) return;
      for (final med in targetMedicines) {
        ref.read(doseLogsProvider.notifier).addLog(
              DoseLog(
                id: const Uuid().v4(),
                medicineId: med.id,
                medicineName: '${med.name} ${med.strength}'.trim(),
                scheduledTime: scheduledTime,
                status: 'skipped',
                actualTime: DateTime.now(),
              ),
            );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang == 'bn' ? 'ওষুধ খাওয়া বাদ দেওয়া হয়েছে' : 'Dose skipped!'),
          backgroundColor: AppColors.error,
        ),
      );
      context.go('/home');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact Header Banner
              FadeSlideIn(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.alarm_on_rounded, color: AppColors.primary, size: 22.0),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang == 'bn' ? 'ওষুধ খাওয়ার সময়' : 'Dose Time',
                              style: const TextStyle(
                                fontSize: 13.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              scheduledTime,
                              style: const TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          '${targetMedicines.length} ${targetMedicines.length == 1 ? (lang == 'bn' ? 'টি ওষুধ' : 'med') : (lang == 'bn' ? 'টি ওষুধ' : 'meds')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12.0),

              // Medicines List
              Expanded(
                child: ListView.builder(
                  itemCount: targetMedicines.length,
                  itemBuilder: (context, index) {
                    final med = targetMedicines[index];
                    return FadeSlideIn(
                      delay: Duration(milliseconds: 100 + (index * 50)),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10.0),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(med.form.icon, color: AppColors.primary, size: 20.0),
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${med.name} ${med.strength}'.trim(),
                                    style: const TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2.0),
                                  Text(
                                    '${lang == 'bn' ? 'ডোজ' : 'Dose'}: ${doseLabel(med, lang)} • ${med.mealRelation}',
                                    style: const TextStyle(
                                      fontSize: 13.0,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (med.instruction.isNotEmpty) ...[
                                    const SizedBox(height: 4.0),
                                    Text(
                                      med.instruction,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Action Buttons
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: Column(
                  children: [
                    // TAKEN
                    SizedBox(
                      height: 64.0,
                      child: AppPrimaryButton(
                        text: lang == 'bn' ? 'খেয়েছি' : 'I took it',
                        icon: Icons.check_circle_rounded,
                        backgroundColor: AppColors.success,
                        onPressed: onTakenAll,
                      ),
                    ),
                    const SizedBox(height: 10.0),

                    // SNOOZE
                    SizedBox(
                      height: 56.0,
                      child: AppPrimaryButton(
                        text: lang == 'bn' ? '১০ মিনিট পর মনে করাও' : 'Remind me in 10 min',
                        icon: Icons.snooze_rounded,
                        backgroundColor: AppColors.warning,
                        onPressed: onSnoozeAll,
                      ),
                    ),
                    const SizedBox(height: 10.0),

                    // SKIP & CALL Row
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56.0,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.block_rounded, color: AppColors.error, size: 22),
                              label: Text(
                                lang == 'bn' ? 'বাদ দিন' : 'Skip',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              ),
                              onPressed: onSkipAll,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: SizedBox(
                            height: 56.0,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.call_rounded, color: Colors.white, size: 22),
                              label: Text(
                                lang == 'bn' ? 'পরিবারকে কল' : 'Call family',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.info,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              ),
                              // Opens the dialer with the saved family/emergency number.
                              onPressed: () => PhoneActions.call(context, patientProfile.emergencyContact, lang: lang),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
