import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/widgets/app_primary_button.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  ConsumerState<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen> {
  late bool _appNotifications;
  late bool _smsReminders;
  late bool _caregiverAlerts;
  late bool _dailySummarySms;
  String _selectedTone = 'Default Tone';

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

    final title = lang == 'bn' ? 'রিমাইন্ডার সেটিংস' : 'Reminder Settings';

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
                  lang == 'bn' ? 'অ্যালার্ম ও নোটিফিকেশন' : 'Alerts & Notifications',
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
                      ? 'আপনার ওষুধ খাওয়ার নোটিফিকেশন সেটিংস এখানে পরিবর্তন করুন।'
                      : 'Manage how and when you want to be reminded about your medicines.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14.5, height: 1.3),
                ),
              ),
              const SizedBox(height: 28.0),

              // Switch Tiles
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
                        title: Text(lang == 'bn' ? 'অ্যাপ নোটিফিকেশন' : 'App Notifications', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        subtitle: Text(lang == 'bn' ? 'ফোনে ইনস্ট্যান্ট অ্যালার্ট' : 'Receive push alerts on this device', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.0, color: AppColors.textSecondary)),
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
                        title: Text(lang == 'bn' ? 'এসএমএস রিমাইন্ডার' : 'SMS Reminders', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        subtitle: Text(lang == 'bn' ? 'ইন্টারনেট ছাড়া রিমাইন্ডার' : 'Send offline SMS reminders to patient', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.0, color: AppColors.textSecondary)),
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
                        title: Text(lang == 'bn' ? 'কেয়ারগিভার অ্যালার্ট' : 'Caregiver Missed-Dose Alerts', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        subtitle: Text(lang == 'bn' ? 'ওষুধ মিস হলে পরিবারের কাছে এসএমএস' : 'Notify family if dose is missed', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.0, color: AppColors.textSecondary)),
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
                        title: Text(lang == 'bn' ? 'দৈনিক সারাংশ এসএমএস' : 'Daily Summary SMS', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        subtitle: Text(lang == 'bn' ? 'প্রতিদিনের কাজের সংক্ষিপ্ত মেসেজ' : 'Send daily adherence brief via SMS', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12.0, color: AppColors.textSecondary)),
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
              const SizedBox(height: 24.0),

              // Tone selector
              FadeSlideIn(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  lang == 'bn' ? 'রিমাইন্ডারের রিংটোন' : 'Reminder Tone',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 10.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.music_note_rounded, color: AppColors.primary),
                    title: Text(_selectedTone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16.0, color: Colors.grey),
                    onTap: () {
                      // Quick alert selection stub
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text(lang == 'bn' ? 'টোন নির্বাচন করুন' : 'Select Tone'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: ['Default Tone', 'Loud Medical Alarm', 'Soft Chime', 'Vibration Only']
                                .map((tone) => ListTile(
                                      title: Text(tone, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      onTap: () {
                                        setState(() {
                                          _selectedTone = tone;
                                        });
                                        Navigator.pop(context);
                                      },
                                    ))
                                .toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20.0),

              // 1-Minute Full-Screen Alarm Real Test Trigger
              FadeSlideIn(
                delay: const Duration(milliseconds: 270),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: AppColors.primary),
                          const SizedBox(width: 8.0),
                          Text(
                            lang == 'bn' ? 'অ্যালার্ম পরীক্ষা (১ মিনিট পর)' : 'Alarm Test (in 1 minute)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: AppColors.primaryDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        lang == 'bn'
                            ? '১ মিনিট পর সরাসরি ফুল-স্ক্রিন অ্যালার্ম বেজে উঠবে। আপনি অ্যাপ খোলা রাখতে পারেন, মিনিমাইজ করতে পারেন বা স্ক্রিন লক করে পরীক্ষা করতে পারেন।'
                            : 'Triggers a full-screen alarm in 1 minute. You can keep the app open, background it, or lock the screen to verify.',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12.0),
                      SizedBox(
                        width: double.infinity,
                        height: 44.0,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.notification_add_rounded, size: 18.0),
                          label: Text(
                            lang == 'bn' ? '🚨 ১ মিনিটের টেস্ট অ্যালার্ম সেট করুন' : '🚨 Set 1-Minute Test Alarm',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          ),
                          onPressed: () async {
                            final meds = ref.read(medicinesProvider);
                            final scheduledDt = await NotificationService.instance.scheduleOneMinuteTestAlarm(meds);
                            if (context.mounted) {
                              final min = scheduledDt.minute.toString().padLeft(2, '0');
                              final hour12 = scheduledDt.hour == 0 ? 12 : (scheduledDt.hour > 12 ? scheduledDt.hour - 12 : scheduledDt.hour);
                              final ampm = scheduledDt.hour >= 12 ? 'PM' : 'AM';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    lang == 'bn'
                                        ? '১ মিনিটের টেস্ট অ্যালার্ম নির্ধারণ করা হয়েছে ($hour12:$min $ampm)। স্ক্রিন লক করে বা মিনিমাইজ করে পরীক্ষা করতে পারেন।'
                                        : 'Test alarm scheduled for $hour12:$min $ampm. You can lock or background the device.',
                                  ),
                                  backgroundColor: AppColors.primaryDark,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: AppPrimaryButton(
                  text: lang == 'bn' ? 'সেটিংস সংরক্ষণ করুন' : 'Save Settings',
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
                        content: Text(lang == 'bn' ? 'সেটিংস সংরক্ষণ করা হয়েছে' : 'Settings saved successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    context.pop();
                  },
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
