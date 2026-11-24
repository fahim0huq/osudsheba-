import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/cloud_sync_provider.dart';
import '../../../core/providers/family_providers.dart';
import '../../../core/services/family_service.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/mock_data_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../shared/widgets/confirm_dialog.dart';

/// "Delete my account" (required by Google Play). Order matters:
///  1. make sure Firebase will accept the deletion (recent sign-in),
///  2. cancel carrier billing and delete the server record (needs the account's ID token),
///  3. delete the Firebase account,
///  4. wipe this phone's data and alarms.
/// Billing is always stopped before anything is deleted, so nobody keeps paying for an
/// account that no longer exists.
class DeleteAccountTile extends ConsumerWidget {
  const DeleteAccountTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).language;
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      child: ListTile(
        leading: const Icon(Icons.person_remove_rounded, color: AppColors.error),
        title: Text(
          lang == 'bn' ? 'আমার অ্যাকাউন্ট মুছে ফেলুন' : 'Delete my account',
          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 15.0),
        ),
        subtitle: Text(
          lang == 'bn'
              ? 'সাবস্ক্রিপশন বাতিল করে অ্যাকাউন্ট ও সব তথ্য স্থায়ীভাবে মুছে দেয়'
              : 'Cancels your subscription and permanently deletes your account and data',
          style: const TextStyle(fontSize: 13.0, color: AppColors.textSecondary),
        ),
        onTap: () => _deleteAccount(context, ref, lang),
      ),
    );
  }
}

String _t(String lang, String bn, String en) => lang == 'bn' ? bn : en;

Future<void> _deleteAccount(BuildContext context, WidgetRef ref, String lang) async {
  final confirmed = await showConfirmDialog(
    context,
    title: _t(lang, 'অ্যাকাউন্ট মুছে ফেলবেন?', 'Delete your account?'),
    message: _t(
      lang,
      'এটি আর ফেরত আনা যাবে না। আপনার সাবস্ক্রিপশন বাতিল হবে (আর টাকা কাটা হবে না), অ্যাকাউন্ট মুছে যাবে, এবং এই ফোনের ওষুধের তালিকা, ইতিহাস ও সব অ্যালার্ম মুছে যাবে।',
      'This cannot be undone. Your subscription will be cancelled (no more charges), your account will be deleted, and your medicine list, history and all alarms on this phone will be erased.',
    ),
    confirmLabel: _t(lang, 'হ্যাঁ, অ্যাকাউন্ট মুছুন', 'Yes, delete my account'),
    cancelLabel: _t(lang, 'না, রেখে দিন', 'No, keep it'),
    icon: Icons.person_remove_rounded,
  );
  if (!confirmed || !context.mounted) return;

  final auth = ref.read(authServiceProvider);
  if (!auth.hasRecentSignIn && !await _signInAgain(context, auth, lang)) return;
  if (!context.mounted) return;

  final uid = ref.read(userUidProvider);
  _showProgress(context, lang);
  String? error;
  try {
    await _deleteServerData(ref, auth);
    await _deleteCloudBackup(ref, uid);
    await ref.read(subscriptionProvider.notifier).clear();
    try {
      await auth.deleteCurrentUser();
    } on RecentSignInRequiredException {
      // Rare: the sign-in expired while the server step ran. Billing is already stopped.
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!context.mounted || !await _signInAgain(context, auth, lang)) {
        error = _t(lang, 'সাবস্ক্রিপশন বাতিল হয়েছে, কিন্তু অ্যাকাউন্ট মোছা হয়নি। আবার চেষ্টা করুন।',
            'Your subscription was cancelled, but the account was not deleted. Please try again.');
        if (context.mounted) _showError(context, lang, error);
        return;
      }
      if (context.mounted) _showProgress(context, lang);
      await auth.deleteCurrentUser();
    }
    await _wipeThisPhone(ref, uid);
  } on SubscriptionStillActiveException {
    error = _t(lang, 'সাবস্ক্রিপশন বাতিল করা যায়নি। কিছুক্ষণ পরে আবার চেষ্টা করুন।',
        'Your subscription could not be cancelled yet. Please try again in a few minutes.');
  } on BillingDataDeleteFailedException {
    error = _t(lang, 'বিল-প্রদানকারী (AppsPro) থেকে আপনার নম্বর মোছা যায়নি, তাই কিছুই মোছা হয়নি। কিছুক্ষণ পরে আবার চেষ্টা করুন।',
        'Your number could not be removed from the billing provider (AppsPro), so nothing was deleted. Please try again later.');
  } catch (e) {
    error = e.toString().replaceFirst('Exception: ', '');
  }

  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop(); // progress dialog
  if (error != null) {
    _showError(context, lang, error);
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(_t(lang, 'আপনার অ্যাকাউন্ট মুছে ফেলা হয়েছে।', 'Your account has been deleted.')),
    backgroundColor: AppColors.success,
  ));
  context.go('/');
}

/// Deletes the server record; cancels carrier billing first if it is still running.
Future<void> _deleteServerData(WidgetRef ref, AuthService auth) async {
  final service = ref.read(subscriptionServiceProvider);
  try {
    await service.deleteAccountData(await auth.getIdToken());
  } on SubscriptionStillActiveException {
    // Throws (and stops everything) if the operator does not confirm the cancellation.
    await ref.read(subscriptionProvider.notifier).unsubscribe();
    await service.deleteAccountData(await auth.getIdToken());
  }
}

/// Deletes the medicines/dose-history backup (needs the account, so before deleting it).
Future<void> _deleteCloudBackup(WidgetRef ref, String? uid) async {
  if (uid == null) return;
  ref.read(appSettingsProvider.notifier).setCloudBackup(false); // nothing re-uploads now
  try {
    // Remove me from the family lists of people I look after, then everything I stored.
    await ref.read(familyServiceProvider)?.leaveAll(uid).timeout(const Duration(seconds: 30));
    await ref.read(cloudSyncProvider).deleteCloudData(uid, includeFamily: true).timeout(const Duration(seconds: 30));
  } on FamilyException catch (e) {
    if (e.error != FamilyError.denied) rethrow;
  } on FirebaseException catch (e) {
    // Rules not deployed yet: the app could never have stored anything there.
    if (e.code != 'permission-denied') rethrow;
  }
}

Future<void> _wipeThisPhone(WidgetRef ref, String? uid) async {
  await NotificationService.instance.cancelAll();
  final storage = ref.read(localStorageProvider);
  await storage.clearAllData(uid);
  ref.read(appSettingsProvider.notifier).resetSettings();
  ref.invalidate(selectedMedicineProvider);
  ref.invalidate(userProfileProvider);
  ref.invalidate(medicinesProvider);
  ref.invalidate(doseLogsProvider);
  ref.invalidate(caregiverAlertsProvider);
  ref.invalidate(patientProfileProvider);
  ref.invalidate(caregiverProfileProvider);
  ref.invalidate(userStorageInitProvider);
  ref.invalidate(subscriptionProvider);
  if (uid != null) await storage.closeUserStorage(uid);
  storage.currentUid = null;
}

/// Asks the user to confirm who they are. Returns true when Firebase accepted it.
Future<bool> _signInAgain(BuildContext context, AuthService auth, String lang) async {
  try {
    switch (auth.signInMethod) {
      case 'password':
        final password = await _askPassword(context, lang);
        if (password == null || password.isEmpty) return false;
        await auth.reauthenticateWithPassword(password);
        return true;
      case 'google.com':
        await auth.reauthenticateWithGoogle();
        return true;
      default:
        // Phone sign-in needs a new SMS code; the simplest safe path is a fresh login.
        if (context.mounted) {
          _showError(context, lang, _t(lang,
              'নিরাপত্তার জন্য প্রথমে লগআউট করে আবার লগইন করুন, তারপর সাথে সাথে অ্যাকাউন্ট মুছুন।',
              'For your security, please log out and log in again, then delete your account straight away.'));
        }
        return false;
    }
  } catch (e) {
    if (context.mounted) _showError(context, lang, e.toString().replaceFirst('Exception: ', ''));
    return false;
  }
}

Future<String?> _askPassword(BuildContext context, String lang) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(_t(lang, 'পাসওয়ার্ড দিন', 'Enter your password')),
      content: TextField(
        controller: controller,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(
          labelText: _t(lang, 'পাসওয়ার্ড', 'Password'),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(_t(lang, 'বাতিল', 'Cancel'))),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text),
          child: Text(_t(lang, 'নিশ্চিত করুন', 'Confirm')),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

void _showProgress(BuildContext context, String lang) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(_t(lang, 'অ্যাকাউন্ট মোছা হচ্ছে…', 'Deleting your account…'))),
        ]),
      ),
    ),
  );
}

void _showError(BuildContext context, String lang, String message) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(_t(lang, 'অ্যাকাউন্ট মোছা যায়নি', 'Account not deleted')),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(_t(lang, 'ঠিক আছে', 'OK'))),
      ],
    ),
  );
}
