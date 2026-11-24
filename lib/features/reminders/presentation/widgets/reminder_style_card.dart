import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/mock_data_service.dart';
import '../../../../core/services/notification_service.dart';

/// Reminder style: a full-screen alarm (sound, spoken medicine names, medicine photo, opens
/// over the lock screen) or only a notification in the notification bar.
class ReminderStyleCard extends ConsumerStatefulWidget {
  const ReminderStyleCard({super.key});

  @override
  ConsumerState<ReminderStyleCard> createState() => _ReminderStyleCardState();
}

class _ReminderStyleCardState extends ConsumerState<ReminderStyleCard> with WidgetsBindingObserver {
  bool _allowed = true; // Android 14+: full-screen alarms allowed for this app

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the system settings page: check again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final ok = await NotificationService.instance.canUseFullScreen();
    if (mounted) setState(() => _allowed = ok);
  }

  Future<void> _choose(bool fullScreen) async {
    ref.read(appSettingsProvider.notifier).setFullScreenAlarms(fullScreen);
    if (fullScreen && !await NotificationService.instance.canUseFullScreen()) {
      await NotificationService.instance.requestFullScreenPermission();
    }
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final bn = settings.language == 'bn';
    final full = settings.fullScreenAlarms;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            bn ? 'রিমাইন্ডার কীভাবে আসবে' : 'How reminders appear',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          _Option(
            selected: full,
            icon: Icons.fullscreen_rounded,
            title: bn ? 'পুরো স্ক্রিনে অ্যালার্ম' : 'Full-screen alarm',
            text: bn
                ? 'শব্দ করে বাজবে, ওষুধের নাম পড়ে শোনাবে আর ওষুধের ছবি দেখাবে। ফোন লক থাকলেও স্ক্রিন জ্বলে উঠবে।'
                : 'Rings, reads the medicine names aloud and shows the medicine photo. Lights up the screen even when the phone is locked.',
            onTap: () => _choose(true),
          ),
          const SizedBox(height: 8),
          _Option(
            selected: !full,
            icon: Icons.notifications_rounded,
            title: bn ? 'শুধু নোটিফিকেশন' : 'Notification only',
            text: bn
                ? 'শব্দসহ একটি নোটিফিকেশন আসবে। চাপ দিলে অ্যালার্মের পাতা খুলবে।'
                : 'A notification with sound appears in the notification bar. Tap it to open the alarm page.',
            onTap: () => _choose(false),
          ),
          if (full && !_allowed) ...[
            const SizedBox(height: 10),
            Text(
              bn
                  ? 'এই ফোনে পুরো স্ক্রিনের অ্যালার্ম এখনো অনুমতি পায়নি, তাই শুধু নোটিফিকেশন আসবে। নিচের বোতাম চেপে OsudSheba-র জন্য চালু করুন।'
                  : 'This phone has not allowed full-screen alarms yet, so only a notification will appear. Tap below and turn it on for OsudSheba.',
              style: const TextStyle(fontSize: 15, color: AppColors.error, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => NotificationService.instance.requestFullScreenPermission().then((_) => _check()),
              icon: const Icon(Icons.settings_rounded),
              label: Text(bn ? 'অনুমতি দিন' : 'Allow full-screen alarms'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                foregroundColor: AppColors.error,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;
  const _Option({
    required this.selected,
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primaryLight : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 22, color: AppColors.primaryDark),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(text, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
