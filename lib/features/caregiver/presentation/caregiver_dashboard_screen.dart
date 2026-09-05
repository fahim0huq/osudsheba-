import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/dashboard_action_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class CaregiverDashboardScreen extends ConsumerWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final alerts = ref.watch(caregiverAlertsProvider);
    final patientProfile = ref.watch(patientProfileProvider);

    // Look for high severity missed dose alert
    final hasMissedDoseAlert = alerts.any((alert) => alert.severity == 'High');
    final missedDoseAlert = alerts.any((alert) => alert.severity == 'High')
        ? alerts.firstWhere((alert) => alert.severity == 'High')
        : (alerts.isNotEmpty ? alerts.first : null);

    final title = lang == 'bn' ? 'তত্ত্বাবধায়ক ড্যাশবোর্ড' : 'Caregiver Dashboard';

    final caregiverProfile = ref.watch(caregiverProfileProvider);
    final caregiverName = caregiverProfile.name.isNotEmpty
        ? caregiverProfile.name
        : (lang == 'bn' ? 'তত্ত্বাবধায়ক' : 'Caregiver');

    final relation = caregiverProfile.relationship.isNotEmpty
        ? caregiverProfile.relationship
        : (lang == 'bn' ? 'রোগী' : 'Patient');

    final logs = ref.watch(doseLogsProvider);
    final now = DateTime.now();
    final todayLogs = logs.where((l) {
      if (l.actualTime == null) return false;
      return l.actualTime!.day == now.day &&
          l.actualTime!.month == now.month &&
          l.actualTime!.year == now.year;
    }).toList();

    final todayTaken = todayLogs.where((l) => l.status == 'taken' || l.status == 'late').length;
    final todayTotal = todayLogs.length;
    final int todayCompliance = todayTotal > 0 ? (todayTaken / todayTotal * 100).toInt() : 100;
    final todayMissed = todayLogs.where((l) => l.status == 'missed').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: AppColors.textPrimary),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Header
              FadeSlideIn(
                child: Text(
                  lang == 'bn' ? 'আসসালামু আলাইকুম, $caregiverName' : 'Assalamu Alaikum, $caregiverName',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 4.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  lang == 'bn' ? 'আপনার রোগীর আজকের ওষুধের খবর' : 'Track and manage your family member\'s doses.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              const SizedBox(height: 24.0),

              // Emergency / Missed Dose Warning Banner
              if (hasMissedDoseAlert) ...[
                FadeSlideIn(
                  delay: const Duration(milliseconds: 150),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.25), width: 1.2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32.0),
                          const SizedBox(width: 14.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  missedDoseAlert?.title ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0, color: AppColors.error),
                                ),
                                const SizedBox(height: 6.0),
                                Text(
                                  missedDoseAlert?.message ?? '',
                                  style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary, fontWeight: FontWeight.w500, height: 1.3),
                                ),
                                const SizedBox(height: 14.0),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size(130.0, 40.0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                                  ),
                                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16.0, color: Colors.white),
                                  label: Text(
                                    lang == 'bn' ? 'রোগীকে কল দিন' : 'Call Patient Now',
                                    style: const TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Calling Patient at ${patientProfile.phone}...'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
              ],

              // Monitored Patient Summary Card
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  lang == 'bn' ? 'পর্যবেক্ষণ তালিকা' : 'Monitored Patient',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 12.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.01),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: InkWell(
                    onTap: () => context.push('/caregiver-patient-detail'),
                    borderRadius: BorderRadius.circular(20.0),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.elderly_rounded, color: AppColors.primary, size: 30.0),
                          ),
                          const SizedBox(width: 16.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${patientProfile.name.isNotEmpty ? patientProfile.name : (lang == 'bn' ? 'রোগী' : 'Patient')} ($relation)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  '${lang == 'bn' ? 'আজকের অগ্রগতি' : 'Today\'s Compliance'}: $todayCompliance%',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 13.0),
                                ),
                                Text(
                                  '${lang == 'bn' ? 'মিসড ডোজ' : 'Missed Doses'}: $todayMissed ${lang == 'bn' ? 'টি মিস হয়েছে' : 'Missed'}',
                                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 13.0),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16.0, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28.0),

              // Caregiver Quick Actions Grid
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Text(
                  lang == 'bn' ? 'তত্ত্বাবধায়ক অ্যাকশন' : 'Quick Actions',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 12.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 350),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12.0,
                  mainAxisSpacing: 12.0,
                  childAspectRatio: 1.22,
                  children: [
                    DashboardActionButton(
                      label: lang == 'bn' ? 'কেয়ারগিভার যুক্ত করুন' : 'Invite Caregiver',
                      icon: Icons.person_add_alt_rounded,
                      color: AppColors.primary,
                      onTap: () => context.push('/caregiver-invite'),
                    ),
                    DashboardActionButton(
                      label: lang == 'bn' ? 'ডিটেইল রিপোর্ট' : 'Patient Details',
                      icon: Icons.analytics_rounded,
                      color: AppColors.accent,
                      onTap: () => context.push('/caregiver-patient-detail'),
                    ),
                    DashboardActionButton(
                      label: lang == 'bn' ? 'অ্যালার্টস' : 'View Alerts',
                      icon: Icons.notifications_active_rounded,
                      color: AppColors.error,
                      onTap: () => context.push('/caregiver-alerts'),
                    ),
                    DashboardActionButton(
                      label: lang == 'bn' ? 'রোগী প্রোফাইল' : 'Patient Settings',
                      icon: Icons.settings_accessibility_rounded,
                      color: Colors.indigo,
                      onTap: () => context.push('/patient-profile-setup'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20.0),
            ],
          ),
        ),
      ),
    );
  }
}
