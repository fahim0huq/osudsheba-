import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/models/mock_models.dart';
import '../../../shared/widgets/medicine_card.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import 'widgets/adherence_summary_card.dart';
import 'widgets/next_dose_card.dart';


import '../../../shared/widgets/empty_state.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  bool _isToday(DateTime? dt) {
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.day == now.day && dt.month == now.month && dt.year == now.year;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final medicines = ref.watch(medicinesProvider);
    final logs = ref.watch(doseLogsProvider);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final todayLogs = logs.where((l) => l.actualTime != null && _isToday(l.actualTime)).toList();

    // Filter active medicines valid for today
    final activeMeds = medicines.where((m) {
      if (m.status != 'active') return false;
      if (m.startDate != null && m.startDate!.isAfter(todayEnd)) return false;
      if (m.endDate != null && m.endDate!.isBefore(todayStart)) return false;
      return true;
    }).toList();

    // Calculate total scheduled dose instances for today and doses taken today
    int todayTotalScheduledDoses = 0;
    int todayTakenCount = 0;

    for (final med in activeMeds) {
      for (final time in med.times) {
        todayTotalScheduledDoses++;
        final isTaken = logs.any((l) =>
            l.medicineId == med.id &&
            l.scheduledTime == time &&
            l.actualTime != null &&
            _isToday(l.actualTime) &&
            (l.status == 'taken' || l.status == 'late'));
        if (isTaken) {
          todayTakenCount++;
        }
      }
    }

    int parseTimeToMinutes(String timeStr) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false).firstMatch(timeStr.trim());
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        final int minute = int.parse(match.group(2)!);
        final String amPm = match.group(3)!.toUpperCase();
        if (amPm == 'PM' && hour < 12) {
          hour += 12;
        } else if (amPm == 'AM' && hour == 12) {
          hour = 0;
        }
        return hour * 60 + minute;
      }
      return 0;
    }

    // Helper to check if a dose log exists for today with status: taken, skipped, or snoozed
    bool isDoseLoggedToday(String medicineId, String scheduledTime) {
      return logs.any((l) =>
          l.medicineId == medicineId &&
          l.scheduledTime == scheduledTime &&
          l.actualTime != null &&
          _isToday(l.actualTime) &&
          (l.status == 'taken' || l.status == 'skipped' || l.status == 'snoozed'));
    }

    Medicine? nextMedicine;
    String? nextDoseTime;

    final List<_PendingDose> pendingDoses = [];
    final currentMinutes = now.hour * 60 + now.minute;

    for (final med in activeMeds) {
      if (med.times.isEmpty) continue;

      // Exclude times that already have a dose log for today
      final remainingTimes = med.times.where((time) => !isDoseLoggedToday(med.id, time)).toList();

      // Sort remaining times chronologically
      remainingTimes.sort((a, b) => parseTimeToMinutes(a).compareTo(parseTimeToMinutes(b)));

      String? selectedTime;
      bool isTomorrow = false;

      // Pick the earliest remaining time that is still in the future
      for (final time in remainingTimes) {
        if (parseTimeToMinutes(time) > currentMinutes) {
          selectedTime = time;
          break;
        }
      }

      // If every time today is done or past, fall back to the earliest scheduled time of the next day
      if (selectedTime == null) {
        final sortedAllTimes = List<String>.from(med.times);
        sortedAllTimes.sort((a, b) => parseTimeToMinutes(a).compareTo(parseTimeToMinutes(b)));
        if (sortedAllTimes.isNotEmpty) {
          selectedTime = sortedAllTimes.first;
          isTomorrow = true;
        }
      }

      if (selectedTime != null) {
        final minutes = parseTimeToMinutes(selectedTime);
        var targetDt = DateTime(now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
        if (isTomorrow) {
          targetDt = targetDt.add(const Duration(days: 1));
        }
        pendingDoses.add(_PendingDose(
          medicine: med,
          time: selectedTime,
          targetDateTime: targetDt,
        ));
      }
    }

    List<Medicine> nextDoseMedicines = [];
    if (pendingDoses.isNotEmpty) {
      pendingDoses.sort((a, b) => a.targetDateTime.compareTo(b.targetDateTime));
      nextMedicine = pendingDoses.first.medicine;
      nextDoseTime = pendingDoses.first.time;

      // Group all medicines scheduled for this exact same next dose time
      nextDoseMedicines = pendingDoses
          .where((p) => p.time == nextDoseTime)
          .map((p) => p.medicine)
          .toSet()
          .toList();
    }

    final greeting = lang == 'bn' ? 'আসসালামু আলাইকুম' : 'Assalamu Alaikum';
    final patientProfile = ref.watch(patientProfileProvider);
    final patientName = patientProfile.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('OsudSheba'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, size: 24),
            tooltip: lang == 'bn' ? 'সেটিংস' : 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting & Name
            FadeSlideIn(
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: const CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      radius: 24,
                      child: Icon(Icons.person_rounded, color: AppColors.primary, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: const TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (patientName.isNotEmpty)
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20.0,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24.0),

            if (medicines.isEmpty)
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: EmptyState(
                  title: lang == 'bn' ? 'ওষুধের তালিকা খালি' : 'No Medicines Scheduled',
                  message: lang == 'bn'
                      ? 'আপনার কোনো ওষুধ যোগ করা নেই। নিজে ওষুধ যোগ করুন অথবা প্রেসক্রিপশন স্ক্যান করুন!'
                      : 'You haven\'t added any medicines yet. Add manually or scan a prescription!',
                  icon: Icons.medical_services_outlined,
                  primaryActionLabel: lang == 'bn' ? 'নিজে ওষুধ যোগ করুন' : 'Add Manually',
                  onPrimaryAction: () => context.go('/add-medicine'),
                  secondaryActionLabel: lang == 'bn' ? 'প্রেসক্রিপশন স্ক্যান করুন' : 'Scan Prescription',
                  onSecondaryAction: () => context.go('/upload-prescription'),
                ),
              )
            else ...[
              // Adherence summary card
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: AdherenceSummaryCard(
                  takenCount: todayTakenCount,
                  totalCount: todayTotalScheduledDoses,
                  language: lang,
                ),
              ),
              const SizedBox(height: 14.0),

              // Next Dose card
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: NextDoseCard(
                  nextMedicine: nextMedicine,
                  nextDoseMedicines: nextDoseMedicines,
                  nextDoseTime: nextDoseTime,
                  language: lang,
                  onTaken: () {
                    if (nextMedicine != null && nextDoseTime != null) {
                      ref.read(doseLogsProvider.notifier).addLog(
                            DoseLog(
                              id: const Uuid().v4(),
                              medicineId: nextMedicine.id,
                              medicineName: '${nextMedicine.name} ${nextMedicine.strength}',
                              scheduledTime: nextDoseTime,
                              status: 'taken',
                              actualTime: DateTime.now(),
                            ),
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(lang == 'bn' ? 'ওষুধ খাওয়া সম্পন্ন হয়েছে' : 'Dose marked as Taken!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  onSkip: () {
                    if (nextMedicine != null && nextDoseTime != null) {
                      ref.read(doseLogsProvider.notifier).addLog(
                            DoseLog(
                              id: const Uuid().v4(),
                              medicineId: nextMedicine.id,
                              medicineName: '${nextMedicine.name} ${nextMedicine.strength}',
                              scheduledTime: nextDoseTime,
                              status: 'skipped',
                              actualTime: DateTime.now(),
                            ),
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(lang == 'bn' ? 'ওষুধ বাদ দেওয়া হয়েছে' : 'Dose marked as Skipped!'),
                          backgroundColor: AppColors.textSecondary,
                        ),
                      );
                    }
                  },
                  onTap: () {
                    if (nextMedicine != null) {
                      ref.read(selectedMedicineProvider.notifier).state = nextMedicine;
                      context.push(
                        '/dose-action',
                        extra: {
                          'medicine': nextMedicine,
                          'scheduledTime': nextDoseTime ?? nextMedicine.times.first,
                        },
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 12.0),

              // Today's Medicines list
              FadeSlideIn(
                delay: const Duration(milliseconds: 600),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppStrings.get('todays_medicines', lang),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/medicines'),
                      child: Text(
                        lang == 'bn' ? 'সব দেখুন' : 'See All',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8.0),

              FadeSlideIn(
                delay: const Duration(milliseconds: 700),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: medicines.length,
                  itemBuilder: (context, index) {
                    final med = medicines[index];
                    // Find today's log status for this medicine
                    final todayMedLogs = todayLogs.where((l) => l.medicineId == med.id).toList();
                    String displayStatus = 'Pending';
                    if (todayMedLogs.any((l) => l.status == 'taken')) {
                      displayStatus = 'Taken';
                    } else if (todayMedLogs.any((l) => l.status == 'skipped')) {
                      displayStatus = 'Skipped';
                    } else if (todayMedLogs.any((l) => l.status == 'snoozed')) {
                      displayStatus = 'Snoozed';
                    } else if (todayMedLogs.any((l) => l.status == 'missed')) {
                      displayStatus = 'Missed';
                    } else {
                      displayStatus = med.status == 'active' ? 'Pending' : med.status;
                    }

                    final displayMed = med.copyWith(status: displayStatus);

                    return MedicineCard(
                      medicine: displayMed,
                      onTap: () {
                        ref.read(selectedMedicineProvider.notifier).state = med;
                        context.push('/medicine-detail', extra: med);
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PendingDose {
  final Medicine medicine;
  final String time;
  final DateTime targetDateTime;

  _PendingDose({
    required this.medicine,
    required this.time,
    required this.targetDateTime,
  });
}
