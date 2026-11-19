import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/alert_text.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class CaregiverAlertsScreen extends ConsumerWidget {
  const CaregiverAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final alerts = ref.watch(caregiverAlertsProvider);

    final title = lang == 'bn' ? 'সতর্কতা অ্যালার্টস' : 'Caregiver Alerts';

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
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12.0),
              FadeSlideIn(
                child: Text(
                  lang == 'bn' ? 'রোগী সতর্কবার্তা তালিকা' : 'Active Compliance Alerts',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                ),
              ),
              const SizedBox(height: 4.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  lang == 'bn'
                      ? 'আপনার রোগীর ওষুধ খাওয়া সংক্রান্ত অ্যালার্টগুলো নিচে দেয়া হলো।'
                      : 'Check safety reports, missed-doses warnings, and refill warnings.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.3),
                ),
              ),
              const SizedBox(height: 20.0),

              // Alerts list
              Expanded(
                child: alerts.isEmpty
                    ? FadeSlideIn(
                        delay: const Duration(milliseconds: 150),
                        child: Center(
                          child: Text(
                            lang == 'bn' ? 'কোন সতর্কবার্তা নেই' : 'No active alerts.',
                            style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : FadeSlideIn(
                        delay: const Duration(milliseconds: 150),
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: alerts.length,
                          itemBuilder: (context, index) {
                            final alert = alerts[index];
                            Color severityColor;
                            IconData severityIcon;

                            switch (alert.severity) {
                              case 'High':
                                severityColor = AppColors.error;
                                severityIcon = Icons.error_outline_rounded;
                                break;
                              case 'Medium':
                                severityColor = AppColors.warning;
                                severityIcon = Icons.warning_amber_rounded;
                                break;
                              case 'Low':
                              default:
                                severityColor = AppColors.info;
                                severityIcon = Icons.info_outline;
                            }

                            return Dismissible(
                              key: Key(alert.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20.0),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                child: const Icon(Icons.delete_rounded, color: Colors.white),
                              ),
                              onDismissed: (_) {
                                ref.read(caregiverAlertsProvider.notifier).removeAlert(alert.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(lang == 'bn' ? 'অ্যালার্ট মুছে ফেলা হয়েছে' : 'Alert cleared!'),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12.0),
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16.0),
                                  border: Border.all(color: severityColor.withValues(alpha: 0.3), width: 1.2),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8.0),
                                      decoration: BoxDecoration(
                                        color: severityColor.withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(severityIcon, color: severityColor, size: 24.0),
                                    ),
                                    const SizedBox(width: 14.0),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                alertSeverityText(alert, lang),
                                                style: TextStyle(
                                                  color: severityColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              Text(
                                                alertTimeText(alert, lang, DateTime.now()),
                                                style: const TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6.0),
                                          Text(
                                            alertTitleText(alert, lang),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15.0,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4.0),
                                          Text(
                                            alertMessageText(alert, lang),
                                            style: const TextStyle(
                                              fontSize: 13.0,
                                              height: 1.3,
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
