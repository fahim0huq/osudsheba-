import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/models/mock_models.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class CaregiverPatientDetailScreen extends ConsumerWidget {
  const CaregiverPatientDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final patient = ref.watch(patientProfileProvider);
    final medicines = ref.watch(medicinesProvider);

    final logs = ref.watch(doseLogsProvider);
    final stats = ref.watch(adherenceStatsProvider);

    final String complianceText;
    final String missedDoseText;
    final Color complianceColor;

    if (medicines.isEmpty) {
      complianceText = lang == 'bn' ? 'ওষুধ নেই' : 'No medicines';
      complianceColor = AppColors.textSecondary;
      missedDoseText = lang == 'bn' ? 'ওষুধ নেই' : 'No medicines';
    } else if (stats.totalLogs == 0) {
      complianceText = lang == 'bn' ? 'তথ্য নেই' : 'No data';
      complianceColor = AppColors.textSecondary;
      missedDoseText = lang == 'bn' ? 'কোনো রেকর্ড নেই' : 'No logs recorded';
    } else {
      complianceText = '${stats.percentage}%';
      complianceColor = stats.percentage >= 80
          ? AppColors.success
          : (stats.percentage >= 50 ? AppColors.warning : AppColors.error);

      final sortedLogs = List<DoseLog>.from(logs);
      sortedLogs.sort((a, b) {
        final aTime = a.actualTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.actualTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      DoseLog? lastMissed;
      for (final log in sortedLogs) {
        if (log.status.toLowerCase() == 'missed' || log.status.toLowerCase() == 'skipped') {
          lastMissed = log;
          break;
        }
      }

      if (lastMissed != null) {
        missedDoseText = '${lastMissed.medicineName} (${lastMissed.scheduledTime})';
      } else {
        missedDoseText = lang == 'bn' ? 'কোনো মিস ডোজ নেই' : 'No missed doses';
      }
    }

    final title = lang == 'bn' ? 'রোগীর বিবরণ' : 'Patient Details';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Profile Card
              FadeSlideIn(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF047857)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.elderly_rounded, color: Colors.white, size: 36),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patient.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: Colors.white),
                              ),
                              const SizedBox(height: 4.0),
                              Text(
                                '${lang == 'bn' ? 'বয়স' : 'Age'}: ${patient.age} • ${lang == 'bn' ? 'রোগী' : 'Patient'}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.0, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                '${lang == 'bn' ? 'ফোন' : 'Phone'}: ${patient.phone}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.0, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),

              // Compliance Score & Missed
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Text(
                              lang == 'bn' ? 'অগ্রগতির স্কোর' : 'Compliance Rate',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6.0),
                            Text(
                              complianceText,
                              style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: complianceColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Text(
                              lang == 'bn' ? 'সর্বশেষ মিস ডোজ' : 'Last Missed Dose',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6.0),
                            Text(
                              missedDoseText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: (medicines.isEmpty || stats.totalLogs == 0 || missedDoseText == (lang == 'bn' ? 'কোনো মিস ডোজ নেই' : 'No missed doses'))
                                    ? AppColors.textSecondary
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),

              // Medical Profile details
              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: const Text(
                  'Clinical History',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 10.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(18.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileRow('Chronic Conditions', patient.chronicConditions),
                      const Divider(height: 24, color: AppColors.border),
                      _buildProfileRow('Allergies', patient.allergies),
                      const Divider(height: 24, color: AppColors.border),
                      _buildProfileRow('Emergency Call Phone', patient.emergencyContact),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28.0),

              // Active Medicine list summary
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: Text(
                  lang == 'bn' ? 'রোগীর ওষুধ এবং স্থিতি' : 'Active Medicines & Daily Actions',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 12.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: medicines.length,
                  itemBuilder: (context, index) {
                    final med = medicines[index];
                    Color statusColor = AppColors.primary;
                    if (med.status == 'Taken') statusColor = AppColors.success;
                    if (med.status == 'Missed') statusColor = AppColors.error;
                    if (med.status == 'Skipped') statusColor = AppColors.textSecondary;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10.0),
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(med.form.icon, color: statusColor, size: 20),
                          ),
                          const SizedBox(width: 14.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${med.name} ${med.strength}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  'Schedule: ${med.times.join(", ")}',
                                  style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              med.status,
                              style: TextStyle(color: statusColor, fontSize: 13.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 13.5),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            value.isNotEmpty ? value : 'None reported',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13.5),
          ),
        ),
      ],
    );
  }
}
