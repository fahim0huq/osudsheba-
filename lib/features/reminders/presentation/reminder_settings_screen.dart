import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/widgets/confirm_dialog.dart';

/// Reminder settings.
///
/// Only settings that actually do something are shown. The previous screens also offered
/// "SMS reminders", "Daily summary SMS", "Missed-dose SMS to family" and a ringtone picker;
/// none of these were implemented (no SMS is ever sent and the tone was never used), so
/// they gave users and caregivers false reassurance and have been removed.
class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  ConsumerState<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen> {
  bool _settingTest = false;

  Future<void> _toggleReminders(bool value, String lang) async {
    if (!value) {
      final confirmed = await showConfirmDialog(
        context,
        title: lang == 'bn' ? 'অ্যালার্ম বন্ধ করবেন?' : 'Turn off medicine alarms?',
        message: lang == 'bn'
            ? 'বন্ধ করলে এই ফোনে কোনো ওষুধের অ্যালার্ম বাজবে না। আপনি কি নিশ্চিত?'
            : 'If you turn this off, NO medicine alarms will ring on this phone. Are you sure?',
        confirmLabel: lang == 'bn' ? 'হ্যাঁ, বন্ধ করুন' : 'Yes, turn off alarms',
        cancelLabel: lang == 'bn' ? 'না, চালু রাখুন' : 'No, keep alarms on',
        icon: Icons.notifications_off_rounded,
      );
      if (!confirmed) return;
    }
    ref.read(appSettingsProvider.notifier).updateToggles(appNotifications: value);
    // Apply immediately: previously the switch was saved but alarms kept (or never
    // started) ringing until the medicine list happened to change.
    await NotificationService.instance.rescheduleAll(
      ref.read(medicinesProvider),
      logs: ref.read(doseLogsProvider),
    );
    if (value) {
      await NotificationService.instance.requestPermissions();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value
            ? (lang == 'bn' ? 'ওষুধের অ্যালার্ম চালু করা হয়েছে' : 'Medicine alarms are on')
            : (lang == 'bn' ? 'ওষুধের অ্যালার্ম বন্ধ করা হয়েছে' : 'Medicine alarms are off')),
        backgroundColor: value ? AppColors.success : AppColors.error,
      ),
    );
  }

  Future<void> _setTestAlarm(String lang) async {
    if (_settingTest) return;
    setState(() => _settingTest = true);
    try {
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang == 'bn' ? 'ওয়েবে অ্যালার্ম কাজ করে না। ফোনের অ্যাপ ব্যবহার করুন।' : 'Alarms do not work in the web version. Please use the phone app.')),
        );
        return;
      }
      await NotificationService.instance.requestPermissions();
      final at = await NotificationService.instance.scheduleOneMinuteTestAlarm();
      if (!mounted) return;
      final hh = at.hour % 12 == 0 ? 12 : at.hour % 12;
      final mm = at.minute.toString().padLeft(2, '0');
      final ampm = at.hour < 12 ? 'AM' : 'PM';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(lang == 'bn'
              ? 'পরীক্ষামূলক অ্যালার্ম $hh:$mm $ampm-এ বাজবে। ফোন লক করে অপেক্ষা করুন।'
              : 'A test alarm will ring at $hh:$mm $ampm. Lock the phone and wait.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang == 'bn' ? 'অ্যালার্ম সেট করা যায়নি: $e' : 'Could not set the test alarm: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _settingTest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final remindersOn = settings.appNotificationsEnabled;

    return Scaffold(
      appBar: AppBar(title: Text(lang == 'bn' ? 'রিমাইন্ডার ও অ্যালার্ম' : 'Reminders & alarms')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: remindersOn ? AppColors.border : AppColors.error, width: remindersOn ? 1 : 2),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                title: Text(
                  lang == 'bn' ? 'ওষুধের অ্যালার্ম' : 'Medicine alarms',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: AppColors.textPrimary),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    remindersOn
                        ? (lang == 'bn' ? 'চালু — প্রতিটি ডোজের সময় ফোনে অ্যালার্ম বাজবে' : 'On — your phone rings at each dose time')
                        : (lang == 'bn' ? 'বন্ধ — কোনো অ্যালার্ম বাজবে না' : 'Off — no alarms will ring'),
                    style: TextStyle(
                      fontSize: 16.0,
                      color: remindersOn ? AppColors.textSecondary : AppColors.error,
                      fontWeight: remindersOn ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                ),
                value: remindersOn,
                onChanged: (v) => _toggleReminders(v, lang),
              ),
            ),
            const SizedBox(height: 12.0),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                title: Text(
                  lang == 'bn' ? 'মিস হওয়া ডোজ দেখান' : 'Show missed doses',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: AppColors.textPrimary),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    lang == 'bn'
                        ? 'এই ফোনের "পরিবার" অংশে মিস হওয়া ডোজের সতর্কতা দেখাবে। (পরিবারের অন্য ফোনে বার্তা যায় না।)'
                        : 'Lists missed-dose alerts in the Family tab on this phone. (Nothing is sent to other phones.)',
                    style: const TextStyle(fontSize: 16.0, color: AppColors.textSecondary),
                  ),
                ),
                value: settings.caregiverAlertsEnabled,
                onChanged: (v) => ref.read(appSettingsProvider.notifier).updateToggles(caregiverAlerts: v),
              ),
            ),
            const SizedBox(height: 24.0),
            Container(
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    lang == 'bn' ? 'অ্যালার্ম পরীক্ষা করুন' : 'Check that alarms work',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    lang == 'bn'
                        ? 'এক মিনিট পরে একটি পরীক্ষামূলক অ্যালার্ম বাজবে। এতে কোনো ডোজ রেকর্ড হয় না। নতুন ফোনে বা ব্যাটারি সেভার চালু থাকলে অবশ্যই একবার পরীক্ষা করুন।'
                        : 'A test alarm rings in one minute. No dose is recorded. Please try this once on every new phone, and if battery saver is on.',
                    style: const TextStyle(fontSize: 16.0, color: AppColors.textPrimary, height: 1.4),
                  ),
                  const SizedBox(height: 14.0),
                  ElevatedButton.icon(
                    onPressed: (!remindersOn || _settingTest) ? null : () => _setTestAlarm(lang),
                    icon: const Icon(Icons.alarm_add_rounded, size: 24),
                    label: Text(lang == 'bn' ? '১ মিনিট পরে পরীক্ষামূলক অ্যালার্ম' : 'Ring a test alarm in 1 minute'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      textStyle: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (NotificationService.instance.exactAlarmsUnavailable) ...[
                    const SizedBox(height: 12.0),
                    Text(
                      lang == 'bn'
                          ? 'এই ফোন সঠিক সময়ের অ্যালার্মের অনুমতি দেয়নি, তাই অ্যালার্ম কয়েক মিনিট দেরিতে বাজতে পারে। ফোনের সেটিংসে "Alarms & reminders" অনুমতি চালু করুন।'
                          : 'This phone has not allowed exact alarms, so reminders may ring a few minutes late. Turn on "Alarms & reminders" for OsudSheba in the phone settings.',
                      style: const TextStyle(fontSize: 15.0, color: AppColors.error, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16.0),
            Text(
              lang == 'bn'
                  ? 'অ্যালার্ম ঠিকমতো বাজাতে: ফোনের সাউন্ড চালু রাখুন, এবং ব্যাটারি সেটিংসে OsudSheba-কে "Unrestricted" বা "No restrictions" দিন।'
                  : 'For reliable alarms: keep the phone sound on, and set OsudSheba to "Unrestricted" / "No restrictions" in the phone\'s battery settings.',
              style: const TextStyle(fontSize: 15.0, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
