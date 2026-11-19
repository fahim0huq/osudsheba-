import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mock_models.dart';
import '../services/auth_service.dart';
import '../services/family_service.dart';
import '../services/mock_data_service.dart';

/// Family sharing. Null when Firebase is not set up (widget tests): screens then show
/// empty lists and nothing is sent.
final familyServiceProvider = Provider<FamilyService?>((ref) {
  if (Firebase.apps.isEmpty) return null;
  return FamilyService(idToken: () => ref.read(authServiceProvider).getIdToken());
});

Stream<T> _forUser<T>(Ref ref, T empty, Stream<T> Function(FamilyService s, String uid) build) {
  final uid = ref.watch(userUidProvider);
  final service = ref.watch(familyServiceProvider);
  if (uid == null || service == null) return Stream.value(empty);
  return build(service, uid);
}

/// People who can see my medicines, or asked to.
final myFamilyProvider = StreamProvider<List<FamilyMember>>(
    (ref) => _forUser(ref, const <FamilyMember>[], (s, uid) => s.watchMyFamily(uid)));

/// People I look after.
final caringProvider = StreamProvider<List<CaredPerson>>(
    (ref) => _forUser(ref, const <CaredPerson>[], (s, uid) => s.watchCaring(uid)));

/// Reminders family members sent me that I have not dismissed yet.
final nudgesProvider =
    StreamProvider<List<Nudge>>((ref) => _forUser(ref, const <Nudge>[], (s, uid) => s.watchNudges(uid)));

/// My access to a person I look after: 'active', 'pending', or null (removed).
final careAccessProvider = StreamProvider.family<String?, String>((ref, patientUid) =>
    _forUser<String?>(ref, null, (s, uid) => s.watchMyAccess(patientUid: patientUid, myUid: uid)));

final careMedicinesProvider = StreamProvider.family<List<Medicine>, String>((ref, patientUid) =>
    _forUser(ref, const <Medicine>[], (s, _) => s.watchMedicines(patientUid)));

final careLogsProvider = StreamProvider.family<List<DoseLog>, String>((ref, patientUid) =>
    _forUser(ref, const <DoseLog>[], (s, _) => s.watchDoseLogs(patientUid)));

/// Registers this phone for push reminders under [uid] (and keeps the token current).
Future<void> registerForPush(FamilyService service, String uid) async {
  try {
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();
    if (token != null) await service.saveDeviceToken(myUid: uid, token: token);
    messaging.onTokenRefresh.listen((t) => service.saveDeviceToken(myUid: uid, token: t));
  } catch (e) {
    debugPrint('[Push] registration failed: $e');
  }
}

/// On sign-out: stop reminders for [uid] arriving on this phone.
Future<void> unregisterFromPush(FamilyService service, String uid) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await service.removeDeviceToken(myUid: uid, token: token);
  } catch (e) {
    debugPrint('[Push] unregister failed: $e');
  }
}
