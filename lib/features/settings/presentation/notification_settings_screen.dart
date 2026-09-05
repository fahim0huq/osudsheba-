import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  late bool _appNotifications;
  late bool _smsReminders;
  late bool _caregiverAlerts;
  late bool _dailySummarySms;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _appNotifications = settings.appNotifications;
    _smsReminders = settings.smsReminders;
    _caregiverAlerts = settings.caregiverAlerts;
    _dailySummarySms = settings.dailySummarySms;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;

    final title = lang == 'bn' ? 'নোটিফিকেশন সেটিংস' : 'Notification Settings';

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
              const SizedBox(height: 10.0),
              FadeSlideIn(
                child: Text(
                  lang == 'bn' ? 'অ্যালার্ট কন্ট্রোল' : 'Alert Controls',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                ),
              ),
              const SizedBox(height: 8.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  lang == 'bn'
                      ? 'আপনার ফোনে ওষুধ খাওয়ার মেসেজ ও বিজ্ঞপ্তি চালু বা বন্ধ করুন।'
                      : 'Turn on/off notifications and message formats for your schedule.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.3),
                ),
              ),
              const SizedBox(height: 28.0),

              FadeSlideIn(
                delay: const Duration(milliseconds: 150),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        activeTrackColor: AppColors.primary,
                        title: Text(lang == 'bn' ? 'স্মার্ট রিমাইন্ডার' : 'App Notifications', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        value: _appNotifications,
                        onChanged: (val) {
                          setState(() {
                            _appNotifications = val;
                          });
                        },
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      SwitchListTile(
                        activeTrackColor: AppColors.primary,
                        title: Text(lang == 'bn' ? 'মোবাইল এসএমএস' : 'SMS Reminders', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        value: _smsReminders,
                        onChanged: (val) {
                          setState(() {
                            _smsReminders = val;
                          });
                        },
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      SwitchListTile(
                        activeTrackColor: AppColors.primary,
                        title: Text(lang == 'bn' ? 'পরিবারে মিসড-ডোজ অ্যালার্ট' : 'Missed Dose Alert to Caregiver', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        value: _caregiverAlerts,
                        onChanged: (val) {
                          setState(() {
                            _caregiverAlerts = val;
                          });
                        },
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      SwitchListTile(
                        activeTrackColor: AppColors.primary,
                        title: Text(lang == 'bn' ? 'দৈনিক রিপোর্টের মেসেজ' : 'Daily Summary Message', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        value: _dailySummarySms,
                        onChanged: (val) {
                          setState(() {
                            _dailySummarySms = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
               const SizedBox(height: 40.0),
 
               FadeSlideIn(
                 delay: const Duration(milliseconds: 200),
                 child: AppPrimaryButton(
                   text: lang == 'bn' ? 'সংরক্ষণ করুন' : 'Save',
                   icon: Icons.check_circle_outline_rounded,
                   onPressed: () {
                     ref.read(appSettingsProvider.notifier).updateToggles(
                           appNotifications: _appNotifications,
                           smsReminders: _smsReminders,
                           caregiverAlerts: _caregiverAlerts,
                           dailySummarySms: _dailySummarySms,
                         );
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(
                         content: Text(lang == 'bn' ? 'সংরক্ষণ করা হয়েছে!' : 'Notifications updated!'),
                         backgroundColor: AppColors.success,
                       ),
                     );
                     context.pop();
                   },
                 ),
               ),
             ],
           ),
         ),
       ),
     );
   }
 }
