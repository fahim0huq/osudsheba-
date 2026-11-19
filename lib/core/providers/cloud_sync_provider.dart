import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cloud_sync_service.dart';
import '../services/mock_data_service.dart';

/// The cloud backup. Uses Firestore when Firebase is set up (the app), and stores nothing
/// otherwise (widget tests).
final cloudSyncProvider = Provider<CloudSyncService>((ref) {
  final service = CloudSyncService(
    backend: Firebase.apps.isEmpty ? NoCloudBackend() : FirestoreBackend(),
    storage: ref.read(localStorageProvider),
    isEnabled: () => ref.read(appSettingsProvider).cloudBackupEnabled,
  );
  ref.onDispose(service.status.dispose);
  return service;
});

/// Runs a backup sync for the signed-in user once their data has loaded, then reloads
/// medicines and dose logs if anything came down from the cloud (which also rebuilds the
/// alarms). Returns true if a sync ran.
Future<bool> runCloudSync(WidgetRef ref) async {
  final uid = ref.read(userUidProvider);
  if (uid == null || !ref.read(appSettingsProvider).cloudBackupEnabled) return false;
  try {
    await ref.read(userStorageInitProvider(uid).future);
  } catch (_) {
    return false;
  }
  final changed = await ref.read(cloudSyncProvider).syncNow(uid);
  if (changed && ref.context.mounted && ref.read(userUidProvider) == uid) {
    ref.invalidate(medicineListProvider);
    ref.invalidate(doseLogProvider);
  }
  return true;
}
