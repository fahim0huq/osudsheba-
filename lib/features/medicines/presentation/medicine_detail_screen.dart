import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/mock_models.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class MedicineDetailScreen extends ConsumerStatefulWidget {
  final Medicine? medicine;

  const MedicineDetailScreen({super.key,
    this.medicine,
  });

  @override
  ConsumerState<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends ConsumerState<MedicineDetailScreen> {
  String? _selectedTime;

  bool _isToday(DateTime? dt) {
    if (dt == null) return false;
    final now = DateTime.now();
    return dt.day == now.day && dt.month == now.month && dt.year == now.year;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    // Use passed medicine, selected medicine, or fallback to the first one in the provider list
    final medList = ref.watch(medicinesProvider);
    final currentMed = widget.medicine ?? ref.watch(selectedMedicineProvider) ?? (medList.isNotEmpty ? medList.first : null);

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
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
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
    final now = DateTime.now();
    final todayMedLogs = logs.where((l) =>
        l.medicineId == currentMed.id &&
        l.actualTime != null &&
        l.actualTime!.day == now.day &&
        l.actualTime!.month == now.month &&
        l.actualTime!.year == now.year).toList();

    // Find next pending time for today to default to
    String? defaultTime;
    if (currentMed.times.isNotEmpty) {
      for (final time in currentMed.times) {
        final isLogged = logs.any((l) =>
            l.medicineId == currentMed.id &&
            l.scheduledTime == time &&
            l.actualTime != null &&
            _isToday(l.actualTime) &&
            (l.status == 'taken' || l.status == 'skipped' || l.status == 'snoozed'));
        if (!isLogged) {
          defaultTime = time;
          break;
        }
      }
      defaultTime ??= currentMed.times.first;
    }
    final activeTime = _selectedTime ?? defaultTime;

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
      displayStatus = currentMed.status == 'active' ? 'Pending' : currentMed.status;
    }

    final title = lang == 'bn' ? 'ওষুধের বিস্তারিত' : 'Medicine Details';

    // Status Styling
    Color statusBgColor;
    Color statusTextColor;
    switch (displayStatus) {
      case 'Taken':
        statusBgColor = const Color(0xFFECFDF5);
        statusTextColor = const Color(0xFF059669);
        break;
      case 'Missed':
        statusBgColor = const Color(0xFFFEF2F2);
        statusTextColor = const Color(0xFFDC2626);
        break;
      case 'Snoozed':
        statusBgColor = const Color(0xFFFFFBEB);
        statusTextColor = const Color(0xFFD97706);
        break;
      case 'Skipped':
        statusBgColor = Colors.grey.shade100;
        statusTextColor = Colors.grey.shade600;
        break;
      default:
        statusBgColor = const Color(0xFFEFF6FF);
        statusTextColor = Colors.blue.shade700;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: AppColors.textSecondary),
            onPressed: () {
              ref.read(selectedMedicineProvider.notifier).state = currentMed;
              context.push('/edit-medicine', extra: currentMed);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: () {
              _showDeleteConfirmation(context, ref, currentMed, lang);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            FadeSlideIn(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24.0),
                  border: Border.all(color: AppColors.border, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.015),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(currentMed.form.icon, size: 48, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16.0),
                    Text(
                      currentMed.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      currentMed.strength,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                    ),
                    const SizedBox(height: 14.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        displayStatus.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: statusTextColor,
                          fontSize: 12.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24.0),

            // Detail sections
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22.0),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      context,
                      icon: Icons.tag_rounded,
                      label: lang == 'bn' ? 'ওষুধের মাত্রা' : 'Dose Amount',
                      value: currentMed.dose,
                    ),
                    const Divider(height: 24, color: AppColors.border),
                    _buildDetailRow(
                      context,
                      icon: Icons.restaurant_rounded,
                      label: lang == 'bn' ? 'খাবারের সাথে সম্পর্ক' : 'Meal Relation',
                      value: currentMed.mealRelation,
                    ),
                    const Divider(height: 24, color: AppColors.border),
                    _buildDetailRow(
                      context,
                      icon: Icons.alarm_rounded,
                      label: lang == 'bn' ? 'রিমাইন্ডারের সময়সমূহ' : 'Reminder Times',
                      value: currentMed.times.join(', '),
                    ),
                    const Divider(height: 24, color: AppColors.border),
                    _buildDetailRow(
                      context,
                      icon: Icons.notes_rounded,
                      label: lang == 'bn' ? 'নির্দেশনা' : 'Instructions',
                      value: currentMed.instruction.isNotEmpty
                          ? currentMed.instruction
                          : (lang == 'bn' ? 'কোন নির্দেশনা নেই' : 'No specific instructions provided.'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20.0),

            // Adherence Tracker card
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: Container(
                padding: const EdgeInsets.all(18.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20.0),
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1.0),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 24.0),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text(
                        lang == 'bn'
                            ? 'গত সপ্তাহে শতভাগ মেনে চলা হয়েছে!'
                            : '100% adherence rate this week!',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36.0),

            if (currentMed.times.length > 1) ...[
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == 'bn' ? 'ওষুধের সময় নির্বাচন করুন' : 'Select Scheduled Time',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: currentMed.times.map((time) {
                          final isSelected = activeTime == time;
                          return ChoiceChip(
                            label: Text(
                              time,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: Colors.grey.shade100,
                            checkmarkColor: Colors.white,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedTime = time;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
            ],

            // Quick Dose Actions
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(doseLogsProvider.notifier).addLog(
                              DoseLog(
                                id: const Uuid().v4(),
                                medicineId: currentMed.id,
                                medicineName: '${currentMed.name} ${currentMed.strength}',
                                scheduledTime: activeTime ?? currentMed.times.first,
                                status: 'skipped',
                                actualTime: DateTime.now(),
                              ),
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang == 'bn' ? 'ওষুধ খাওয়া বাদ দেয়া হয়েছে' : 'Dose skipped!'),
                            backgroundColor: AppColors.textSecondary,
                          ),
                        );
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(color: Colors.grey.shade300, width: 1.0),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.block_rounded, size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              lang == 'bn' ? 'বাদ দিন' : 'Skip',
                              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ref.read(doseLogsProvider.notifier).addLog(
                              DoseLog(
                                id: const Uuid().v4(),
                                medicineId: currentMed.id,
                                medicineName: '${currentMed.name} ${currentMed.strength}',
                                scheduledTime: activeTime ?? currentMed.times.first,
                                status: 'snoozed',
                                actualTime: DateTime.now(),
                              ),
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(lang == 'bn' ? 'অ্যালার্ম থামানো হয়েছে' : 'Snoozed for 10 mins!'),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(color: Colors.orange.shade200, width: 1.0),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.snooze_rounded, size: 18, color: Colors.orange),
                            const SizedBox(width: 6),
                            Text(
                              lang == 'bn' ? 'দেরি হবে' : 'Snooze',
                              style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12.0),
            FadeSlideIn(
              delay: const Duration(milliseconds: 450),
              child: AppPrimaryButton(
                text: lang == 'bn' ? 'খেয়েছি' : 'Mark as Taken',
                icon: Icons.check_circle_outline_rounded,
                onPressed: () {
                  ref.read(doseLogsProvider.notifier).addLog(
                        DoseLog(
                          id: const Uuid().v4(),
                          medicineId: currentMed.id,
                          medicineName: '${currentMed.name} ${currentMed.strength}',
                          scheduledTime: activeTime ?? currentMed.times.first,
                          status: 'taken',
                          actualTime: DateTime.now(),
                        ),
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang == 'bn' ? 'ওষুধ খাওয়া সফল হয়েছে' : 'Dose marked as Taken!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20.0),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 22.0),
        const SizedBox(width: 14.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  fontSize: 13.0,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, Medicine medicine, String lang) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(lang == 'bn' ? 'ওষুধ মুছুন' : 'Delete Medicine'),
          content: Text(lang == 'bn'
              ? 'আপনি কি নিশ্চিত যে আপনি "${medicine.name}" ওষুধটি তালিকা থেকে মুছে ফেলতে চান?'
              : 'Are you sure you want to delete "${medicine.name}"? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(lang == 'bn' ? 'বাতিল' : 'Cancel'),
            ),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: Text(lang == 'bn' ? 'মুছে ফেলুন' : 'Delete'),
            ),
          ],
        );
      },
    );
  }
}
