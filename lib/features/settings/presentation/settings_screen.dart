import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/models/subscription.dart';
import '../../../shared/widgets/fade_slide_in.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final lang = settings.language;
    final profile = ref.watch(userProfileProvider);
    final subAsync = ref.watch(subscriptionProvider);
    final sub = subAsync.value;

    final title = lang == 'bn' ? 'সেটিংস' : 'Settings';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Profile Card Stub
            FadeSlideIn(
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
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  leading: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 26),
                  ),
                  title: Text(
                    profile.name.isNotEmpty ? profile.name : (lang == 'bn' ? 'প্রোফাইল অসম্পূর্ণ' : 'Incomplete Profile'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    profile.phone.isNotEmpty ? profile.phone : (lang == 'bn' ? 'কোনো ফোন নম্বর নেই' : 'No phone number'),
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.0, color: AppColors.textSecondary),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                    onPressed: () {
                      final activeRole = profile.role != 'None' ? profile.role : settings.userRole;
                      if (activeRole == 'Patient') {
                        context.push('/patient-profile-setup');
                      } else if (activeRole == 'Caregiver') {
                        context.push('/caregiver-profile-setup');
                      } else {
                        context.push('/role-selection');
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // Subscription & Premium Tile
            FadeSlideIn(
              delay: const Duration(milliseconds: 50),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: (sub?.isEntitled ?? false) ? AppColors.primary : AppColors.border,
                    width: (sub?.isEntitled ?? false) ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                  ),
                  title: Text(
                    lang == 'bn' ? 'সাবস্ক্রিপশন ও প্রিমিয়াম' : 'Subscription & Premium',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    (sub?.isEntitled ?? false)
                        ? (lang == 'bn' ? 'সক্রিয় (দৈনিক ২ টাকা)' : 'Active (Daily BDT 2)')
                        : (lang == 'bn' ? 'সাবস্ক্রিপশন প্রয়োজন' : 'Subscription Required'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: (sub?.isEntitled ?? false) ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () => _showSubscriptionManagementModal(context, ref, lang, sub),
                ),
              ),
            ),
            const SizedBox(height: 8.0),

            // Settings options
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: _buildSettingTile(
                context,
                icon: Icons.language_rounded,
                title: lang == 'bn' ? 'ভাষা সেটিংস (Language)' : 'Language Settings',
                onTap: () => context.push('/language-settings'),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: _buildSettingTile(
                context,
                icon: Icons.alarm_rounded,
                title: lang == 'bn' ? 'রিমাইন্ডার সেটিংস' : 'Reminder Settings',
                onTap: () => context.push('/reminder-settings'),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 200),
              child: _buildSettingTile(
                context,
                icon: Icons.notifications_rounded,
                title: lang == 'bn' ? 'নোটিফিকেশন সেটিংস' : 'Notification Settings',
                onTap: () => context.push('/notification-settings'),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: _buildSettingTile(
                context,
                icon: Icons.security_rounded,
                title: lang == 'bn' ? 'গোপনীয়তা ও নিরাপত্তা' : 'Privacy & Security',
                onTap: () => context.push('/privacy'),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 300),
              child: _buildSettingTile(
                context,
                icon: Icons.people_rounded,
                title: lang == 'bn' ? 'তত্ত্বাবধায়ক/পারিবারিক এক্সেস' : 'Family/Caregiver Access',
                onTap: () => context.push('/caregiver'),
              ),
            ),
            FadeSlideIn(
              delay: const Duration(milliseconds: 350),
              child: _buildSettingTile(
                context,
                icon: Icons.info_rounded,
                title: lang == 'bn' ? 'ওষুধসেবা সম্পর্কে' : 'About OsudSheba',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'OsudSheba',
                    applicationVersion: '1.0.0 (Prototype)',
                    applicationIcon: const Icon(Icons.healing_rounded, color: AppColors.primary, size: 40.0),
                    children: [
                      const Text('AI-powered medicine reminder platform custom designed for patients in Bangladesh.'),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 36.0),

            // Logout Button
            FadeSlideIn(
              delay: const Duration(milliseconds: 400),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.2), width: 1.0),
                ),
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                  title: Text(
                    lang == 'bn' ? 'লগআউট' : 'Logout',
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15.0),
                  ),
                  onTap: () async {
                    final uid = ref.read(userUidProvider);
                    
                    // Mark session as logged out in the profile
                    ref.read(userProfileProvider.notifier).clearSessionOnly();
                    
                    // Sign out of Firebase first and wait for completion
                    await ref.read(authServiceProvider).signOut();
                    
                    // Invalidate all user-specific provider states
                    ref.invalidate(selectedMedicineProvider);
                    ref.invalidate(userProfileProvider);
                    ref.invalidate(medicinesProvider);
                    ref.invalidate(doseLogsProvider);
                    ref.invalidate(caregiverAlertsProvider);
                    ref.invalidate(patientProfileProvider);
                    ref.invalidate(caregiverProfileProvider);
                    ref.invalidate(userStorageInitProvider);
                    
                    // Clear and invalidate subscription provider
                    await ref.read(subscriptionProvider.notifier).clear();
                    ref.invalidate(subscriptionProvider);
                    
                    // Close the old user's Hive storage boxes
                    if (uid != null) {
                      await ref.read(localStorageProvider).closeUserStorage(uid);
                    }
                    
                    // Reset currentUid context to null
                    ref.read(localStorageProvider).currentUid = null;
                    
                    if (context.mounted) {
                      context.go('/');
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12.0),

            // Delete All Data Button
            FadeSlideIn(
              delay: const Duration(milliseconds: 450),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.white),
                  title: Text(
                    lang == 'bn' ? 'সব লোকাল ডেটা মুছুন (ঝুঁকিপূর্ণ)' : 'Delete All Local Data (Dangerous)',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.0),
                  ),
                  onTap: () {
                    _showDeleteAllDataConfirmation(context, ref, lang, profile.id);
                  },
                ),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12.0),
              FadeSlideIn(
                delay: const Duration(milliseconds: 500),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.0),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.bug_report_rounded, color: AppColors.primary),
                    title: Text(
                      lang == 'bn' ? 'টেস্ট নোটিফিকেশন (৩০ সেকেন্ড)' : 'Test Notification (30s)',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15.0),
                    ),
                    onTap: () async {
                      await NotificationService.instance.scheduleTestNotification();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(lang == 'bn' ? 'টেস্ট নোটিফিকেশন শিডিউল করা হয়েছে (৩০ সেকেন্ড)' : 'Test notification scheduled in 30 seconds!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showDeleteAllDataConfirmation(BuildContext context, WidgetRef ref, String lang, String profileId) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_rounded, color: AppColors.error, size: 24),
              const SizedBox(width: 8),
              Text(lang == 'bn' ? 'সব ডেটা মুছে ফেলার নিশ্চিতকরণ' : 'Confirm Data Deletion'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang == 'bn'
                    ? 'এই কাজটি আপনার সমস্ত ওষুধ, ডোজ লগ, প্রোফাইল সেটিংস মুছে ফেলবে এবং এটি আর ফেরত পাওয়া যাবে না।'
                    : 'This action will delete all medicines, dose logs, and profile settings permanently. This cannot be undone.',
                style: const TextStyle(fontSize: 14.0),
              ),
              const SizedBox(height: 16.0),
              Text(
                lang == 'bn'
                    ? 'নিশ্চিত করতে নিচের বক্সে "DELETE" লিখুন:'
                    : 'Type "DELETE" in the box below to confirm:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0),
              ),
              const SizedBox(height: 8.0),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  hintText: 'DELETE',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(lang == 'bn' ? 'বাতিল' : 'Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (textController.text.trim() == 'DELETE') {
                  Navigator.of(context).pop();
                  
                  // Wipe Hive
                  await ref.read(localStorageProvider).clearAllData(profileId);

                  // Reset Providers
                  ref.read(appSettingsProvider.notifier).resetSettings();
                  ref.read(userProfileProvider.notifier).resetProfile();
                  ref.read(medicinesProvider.notifier).reset();
                  ref.read(doseLogsProvider.notifier).reset();
                  ref.read(caregiverAlertsProvider.notifier).reset();
                  ref.read(patientProfileProvider.notifier).reset();
                  ref.read(caregiverProfileProvider.notifier).reset();

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang == 'bn' ? 'সমস্ত ডেটা মুছে ফেলা হয়েছে' : 'All local data cleared successfully'),
                      backgroundColor: AppColors.error,
                    ),
                  );

                  context.go('/onboarding');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(lang == 'bn' ? 'সঠিক শব্দ লিখুন' : 'Please type DELETE to confirm'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: Text(lang == 'bn' ? 'নিশ্চিত করুন' : 'Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _showSubscriptionManagementModal(BuildContext context, WidgetRef ref, String lang, Subscription? sub) {
    final isBn = lang == 'bn';
    final isEntitled = sub?.isEntitled ?? false;
    final maskedPhone = sub?.phoneMasked ?? (isBn ? 'সংযুক্ত নম্বর নেই' : 'No number attached');
    final formattedDate = sub?.subscribedAt != null
        ? DateFormat('dd MMM yyyy').format(sub!.subscribedAt!)
        : (isBn ? 'উপলব্ধ নয়' : 'N/A');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(24.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              const SizedBox(height: 18.0),
              Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    isBn ? 'সাবস্ক্রিপশন ব্যবস্থাপনা' : 'Manage Subscription',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const Divider(height: 24.0),
              if (!isEntitled) ...[
                Text(
                  isBn 
                    ? 'আপনার কোনো সক্রিয় সাবস্ক্রিপশন নেই। ওষুধসেবার প্রিমিয়াম ফিচারসমূহ ব্যবহার করতে সাবস্ক্রাইব করুন।' 
                    : 'You do not have an active subscription. Subscribe to unlock all OsudSheba premium features.',
                  style: const TextStyle(fontSize: 14.0, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20.0),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(modalContext).pop();
                      context.push('/subscription');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    child: Text(
                      isBn ? 'সাবস্ক্রাইব করুন' : 'Subscribe Now',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
                    ),
                  ),
                ),
              ] else ...[
                _buildInfoRow(isBn ? 'স্ট্যাটাস:' : 'Status:', isBn ? 'সক্রিয় (Active)' : 'Active', color: AppColors.success),
                _buildInfoRow(isBn ? 'প্ল্যান:' : 'Plan:', isBn ? 'দৈনিক ২.০০ টাকা (Daily BDT 2.00)' : 'Daily BDT 2.00'),
                _buildInfoRow(isBn ? 'মোবাইল নম্বর:' : 'Phone Number:', maskedPhone),
                _buildInfoRow(isBn ? 'শুরুর তারিখ:' : 'Subscribed Since:', formattedDate),
                _buildInfoRow(isBn ? 'বিলিং মাধ্যম:' : 'Carrier Provider:', 'BDApps (Robi / Airtel)'),
                const SizedBox(height: 24.0),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                    label: Text(
                      isBn ? 'সাবস্ক্রিপশন বাতিল করুন' : 'Cancel Subscription',
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                    ),
                    onPressed: () {
                      _showCancelConfirmationDialog(context, ref, isBn, modalContext);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12.0),
            ],
          ),
        );
      },
    );
  }

  void _showCancelConfirmationDialog(BuildContext context, WidgetRef ref, bool isBn, BuildContext modalContext) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_rounded, color: AppColors.error),
              const SizedBox(width: 8),
              Text(isBn ? 'সাবস্ক্রিপশন বাতিল' : 'Cancel Subscription'),
            ],
          ),
          content: Text(
            isBn 
              ? 'আপনি কি নিশ্চিতভাবে সাবস্ক্রিপশন বাতিল করতে চান? বাতিল করলে ওষুধসেবার প্রিমিয়াম ফিচারসমূহ অবিলম্বে বন্ধ হয়ে যাবে।' 
              : 'Are you sure you want to cancel your subscription? You will lose access to premium features immediately.',
            style: const TextStyle(fontSize: 14.0),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(isBn ? 'না' : 'No'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                Navigator.of(modalContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isBn ? 'সাবস্ক্রিপশন বাতিল করা হচ্ছে...' : 'Cancelling subscription...'),
                  ),
                );

                await ref.read(subscriptionProvider.notifier).unsubscribe();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isBn ? 'সাবস্ক্রিপশন বাতিল হয়েছে।' : 'Subscription cancelled successfully.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  context.go('/subscription');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: Text(isBn ? 'হ্যাঁ, বাতিল করুন' : 'Yes, Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
