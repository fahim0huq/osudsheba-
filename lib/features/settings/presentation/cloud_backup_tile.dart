import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/cloud_sync_provider.dart';
import '../../../core/services/cloud_sync_service.dart';
import '../../../core/services/mock_data_service.dart';

/// Settings: "Back up to my account" (opt-in), with the last backup time.
class CloudBackupTile extends ConsumerStatefulWidget {
  const CloudBackupTile({super.key});

  @override
  ConsumerState<CloudBackupTile> createState() => _CloudBackupTileState();
}

class _CloudBackupTileState extends ConsumerState<CloudBackupTile> {
  @override
  void initState() {
    super.initState();
    final uid = ref.read(userUidProvider);
    if (uid != null) ref.read(cloudSyncProvider).loadStatus(uid);
  }

  String _t(String bn, String en) => ref.read(appSettingsProvider).language == 'bn' ? bn : en;

  Future<void> _turnOn() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('অ্যাকাউন্টে ব্যাকআপ রাখবেন?', 'Back up to your account?')),
        content: Text(_t(
          'আপনার ওষুধের তালিকা ও কোন ওষুধ কখন খেয়েছেন তার ইতিহাস আপনার অ্যাকাউন্টে (Google Firebase-এ) সংরক্ষিত হবে, যাতে নতুন ফোনে বা অ্যাপ আবার ইনস্টল করলে সব ফিরে পান। শুধু আপনি এগুলো দেখতে পারবেন। যেকোনো সময় বন্ধ করে ব্যাকআপ মুছে দিতে পারবেন।',
          'Your medicine list and your dose history (what you took and when) will be stored in your account (on Google Firebase), so they come back on a new phone or after reinstalling. Only you can see them. You can turn this off and delete the backup at any time.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_t('না', 'Not now'))),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(_t('হ্যাঁ, ব্যাকআপ চালু করুন', 'Yes, turn on'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    ref.read(appSettingsProvider.notifier).setCloudBackup(true);
    await _backUpNow();
  }

  Future<void> _turnOff() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t('ব্যাকআপ বন্ধ করবেন?', 'Turn off backup?')),
        content: Text(_t(
          'এই ফোনের তথ্য যেমন আছে তেমনই থাকবে। অ্যাকাউন্টে থাকা ব্যাকআপ রাখবেন নাকি মুছে দেবেন?',
          'Everything on this phone stays as it is. Keep the copy in your account, or delete it?',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(_t('বাতিল', 'Cancel'))),
          TextButton(onPressed: () => Navigator.of(ctx).pop('keep'), child: Text(_t('রেখে দিন', 'Keep backup'))),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('delete'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(_t('মুছে দিন', 'Delete backup')),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    ref.read(appSettingsProvider.notifier).setCloudBackup(false);
    if (choice == 'delete') {
      final uid = ref.read(userUidProvider);
      String message;
      try {
        if (uid != null) await ref.read(cloudSyncProvider).deleteCloudData(uid);
        message = _t('অ্যাকাউন্টের ব্যাকআপ মুছে ফেলা হয়েছে।', 'The backup in your account was deleted.');
      } catch (_) {
        message = _t('ব্যাকআপ মোছা যায়নি। ইন্টারনেট চালু করে আবার চেষ্টা করুন।',
            'Could not delete the backup. Connect to the internet and try again.');
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _backUpNow() async {
    await runCloudSync(ref);
    if (!mounted) return;
    final error = ref.read(cloudSyncProvider).status.value.error;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error == null
          ? _t('ব্যাকআপ সম্পূর্ণ হয়েছে।', 'Backup complete.')
          : _t('ব্যাকআপ হয়নি। ইন্টারনেট চালু করে আবার চেষ্টা করুন।', 'Backup did not finish. Connect to the internet and try again.')),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
    ));
  }

  String _statusText(bool enabled, SyncStatus s) {
    if (!enabled) return _t('বন্ধ: তথ্য শুধু এই ফোনে আছে', 'Off: your data is only on this phone');
    if (s.syncing) return _t('ব্যাকআপ হচ্ছে…', 'Backing up…');
    if (s.error != null) return _t('শেষ ব্যাকআপ হয়নি, পরে আবার চেষ্টা হবে', 'Last backup did not finish; will retry');
    if (s.lastSync == null) return _t('এখনো ব্যাকআপ হয়নি', 'Not backed up yet');
    return '${_t('শেষ ব্যাকআপ', 'Last backup')}: ${DateFormat('d MMM, h:mm a').format(s.lastSync!)}';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(appSettingsProvider.select((s) => s.cloudBackupEnabled));
    final signedIn = ref.watch(userUidProvider) != null;
    final service = ref.watch(cloudSyncProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.border),
      ),
      child: ValueListenableBuilder<SyncStatus>(
        valueListenable: service.status,
        builder: (context, status, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              secondary: Icon(
                enabled ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                color: AppColors.primary,
              ),
              title: Text(
                _t('অ্যাকাউন্টে ব্যাকআপ', 'Back up to my account'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0, color: AppColors.textPrimary),
              ),
              subtitle: Text(
                _statusText(enabled, status),
                style: TextStyle(
                  fontSize: 13.0,
                  color: enabled && status.error != null ? AppColors.error : AppColors.textSecondary,
                ),
              ),
              value: enabled,
              onChanged: !signedIn ? null : (on) => on ? _turnOn() : _turnOff(),
            ),
            if (enabled)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
                  child: TextButton.icon(
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    label: Text(_t('এখনই ব্যাকআপ', 'Back up now')),
                    onPressed: status.syncing ? null : _backUpNow,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
