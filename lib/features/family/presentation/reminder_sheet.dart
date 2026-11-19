import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/caregiver_sms.dart';

/// How a caregiver's reminder is sent.
enum ReminderMethod { notification, sms, changeNumber }

/// Asks how to send the reminder: a free notification in the app, or an SMS from the
/// caregiver's own SIM (their operator charges its normal SMS rate).
Future<ReminderMethod?> showReminderMethodSheet(BuildContext context, {required bool bn, String? phone}) {
  String t(String b, String e) => bn ? b : e;
  return showModalBottomSheet<ReminderMethod>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(t('কীভাবে পাঠাবেন?', 'How do you want to send it?'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_rounded, color: AppColors.primary),
            title: Text(t('অ্যাপে নোটিফিকেশন', 'Notification in the app')),
            subtitle: Text(t('বিনা খরচে, দুই ফোনেই ইন্টারনেট লাগে', 'Free; both phones need internet')),
            onTap: () => Navigator.of(ctx).pop(ReminderMethod.notification),
          ),
          ListTile(
            leading: const Icon(Icons.sms_rounded, color: AppColors.primary),
            title: Text(t('এসএমএস (আপনার সিম থেকে)', 'SMS (from your SIM)')),
            subtitle: Text(phone == null
                ? t('আপনার অপারেটর সাধারণ এসএমএস চার্জ কাটবে। প্রথমে নম্বর দিতে হবে।',
                    'Your operator charges its normal SMS rate. You will enter their number first.')
                : t('$phone-এ। আপনার অপারেটর সাধারণ এসএমএস চার্জ কাটবে।',
                    'To $phone. Your operator charges its normal SMS rate.')),
            trailing: phone == null
                ? null
                : IconButton(
                    tooltip: t('নম্বর বদলান', 'Change number'),
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => Navigator.of(ctx).pop(ReminderMethod.changeNumber),
                  ),
            onTap: () => Navigator.of(ctx).pop(ReminderMethod.sms),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Asks for the person's mobile number. Returns it as "01XXXXXXXXX", or null if cancelled.
Future<String?> askMobileNumber(BuildContext context, {required bool bn, required String name, String? current}) {
  String t(String b, String e) => bn ? b : e;
  final controller = TextEditingController(text: current ?? '');
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void save() {
          final n = normalizeBdMobile(controller.text);
          if (n == null) {
            setState(() => error = t('সঠিক মোবাইল নম্বর দিন, যেমন 01712345678', 'Enter a valid mobile number, e.g. 01712345678'));
          } else {
            Navigator.of(ctx).pop(n);
          }
        }

        return AlertDialog(
          title: Text(t('$name-এর মোবাইল নম্বর', "$name's mobile number")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('নম্বরটি শুধু আপনার অ্যাকাউন্টে থাকবে, এসএমএস পাঠাতে।', 'The number is kept only in your account, to send SMS.'),
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.phone,
                onSubmitted: (_) => save(),
                decoration: InputDecoration(hintText: '01XXXXXXXXX', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t('বাতিল', 'Cancel'))),
            ElevatedButton(onPressed: save, child: Text(t('সংরক্ষণ', 'Save'))),
          ],
        );
      },
    ),
  );
}
