import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/mock_models.dart';
import 'cloud_sync_service.dart';
import 'subscription_service.dart';

/// Family sharing (Phase 2 of docs/FAMILY_SHARING_PLAN.md). Every user can be looked after
/// (they invite family) and can look after others (they join with a code), at the same time.
/// Access rules are enforced by firestore.rules, not by this class.

/// Someone who can see my medicines (or asked to).
class FamilyMember {
  const FamilyMember({required this.uid, required this.name, required this.active});
  final String uid;
  final String name;
  final bool active; // false = waiting for my approval
}

/// Someone I look after.
class CaredPerson {
  const CaredPerson({required this.uid, required this.name});
  final String uid;
  final String name;
}

/// A reminder a caregiver sent me.
class Nudge {
  const Nudge({required this.id, required this.fromName, required this.message, this.sentAt});
  final String id;
  final String fromName;
  final String message;
  final DateTime? sentAt;
}

enum FamilyError { notFound, expired, ownCode, network, denied }

class FamilyException implements Exception {
  const FamilyException(this.error);
  final FamilyError error;
  @override
  String toString() => 'FamilyException($error)';
}

/// Invite codes: no 0/O or 1/I, which are easy to mix up when read aloud or typed.
const String kInviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const int kInviteLength = 8;
const Duration kInviteValidFor = Duration(hours: 48);

String newInviteCode([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(kInviteLength, (_) => kInviteAlphabet[r.nextInt(kInviteAlphabet.length)]).join();
}

/// Upper-cases and drops spaces/dashes, so "abcd-2345" works.
String normalizeInviteCode(String input) => input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

class FamilyService {
  FamilyService({FirebaseFirestore? db, this.idToken}) : _dbOverride = db;

  final FirebaseFirestore? _dbOverride;
  /// The signed-in user's Firebase ID token, for the server's push endpoint.
  final Future<String?> Function()? idToken;
  FirebaseFirestore get _db => _dbOverride ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const FamilyException(FamilyError.denied);
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') throw const FamilyException(FamilyError.network);
      rethrow;
    }
  }

  // ---------- As the person being looked after ----------

  /// Creates a one-time code (valid [kInviteValidFor]) a family member can use to ask for access.
  Future<({String code, DateTime expiresAt})> createInvite({required String myUid, required String myName}) =>
      _guard(() async {
        final code = newInviteCode();
        final expiresAt = DateTime.now().add(kInviteValidFor);
        await _db.collection('invites').doc(code).set({
          'patientUid': myUid,
          'patientName': myName,
          'expiresAt': Timestamp.fromDate(expiresAt),
          'createdAt': FieldValue.serverTimestamp(),
        });
        return (code: code, expiresAt: expiresAt);
      });

  Stream<List<FamilyMember>> watchMyFamily(String myUid) =>
      _user(myUid).collection('family').snapshots().map((s) => [
            for (final d in s.docs)
              FamilyMember(
                uid: d.id,
                name: (d.data()['caregiverName'] as String?)?.trim().isNotEmpty == true
                    ? d.data()['caregiverName'] as String
                    : '?',
                active: d.data()['status'] == 'active',
              ),
          ]);

  Future<void> approve({required String myUid, required String caregiverUid}) => _guard(() =>
      _user(myUid).collection('family').doc(caregiverUid).update({
        'status': 'active',
        'approvedAt': FieldValue.serverTimestamp(),
      }));

  /// Removes a family member (or declines a request). Their access ends immediately.
  Future<void> removeFamily({required String myUid, required String caregiverUid}) =>
      _guard(() => _user(myUid).collection('family').doc(caregiverUid).delete());

  Stream<List<Nudge>> watchNudges(String myUid) =>
      _user(myUid).collection('nudges').orderBy('sentAt').snapshots().map((s) => [
            for (final d in s.docs)
              Nudge(
                id: d.id,
                fromName: d.data()['fromName'] as String? ?? '',
                message: d.data()['message'] as String? ?? '',
                sentAt: (d.data()['sentAt'] as Timestamp?)?.toDate(),
              ),
          ]);

  Future<void> dismissNudge({required String myUid, required String id}) =>
      _guard(() => _user(myUid).collection('nudges').doc(id).delete());

  // ---------- As a caregiver ----------

  /// Asks for access with a code. Returns the person's name; they still have to approve.
  Future<String> join({required String code, required String myUid, required String myName}) => _guard(() async {
        final normalized = normalizeInviteCode(code);
        if (normalized.length != kInviteLength) throw const FamilyException(FamilyError.notFound);
        final invite = await _db.collection('invites').doc(normalized).get();
        final data = invite.data();
        if (!invite.exists || data == null) throw const FamilyException(FamilyError.notFound);
        final patientUid = data['patientUid'] as String;
        final patientName = data['patientName'] as String? ?? '';
        if (patientUid == myUid) throw const FamilyException(FamilyError.ownCode);
        final expires = (data['expiresAt'] as Timestamp?)?.toDate();
        if (expires == null || expires.isBefore(DateTime.now())) throw const FamilyException(FamilyError.expired);

        // Already approved or already waiting: keep that (only the patient may change it).
        final mine = _user(patientUid).collection('family').doc(myUid);
        final existing = await mine.get();
        if (!existing.exists) {
          await mine.set({
          'status': 'pending',
          'inviteCode': normalized,
          'caregiverName': myName,
          'requestedAt': FieldValue.serverTimestamp(),
          });
        }
        await _user(myUid).collection('caring').doc(patientUid).set({
          'patientName': patientName,
          'addedAt': FieldValue.serverTimestamp(),
        });
        return patientName;
      });

  Stream<List<CaredPerson>> watchCaring(String myUid) =>
      _user(myUid).collection('caring').snapshots().map((s) => [
            for (final d in s.docs) CaredPerson(uid: d.id, name: d.data()['patientName'] as String? ?? '?'),
          ]);

  /// 'active', 'pending', or null when the person removed me (or never approved).
  Stream<String?> watchMyAccess({required String patientUid, required String myUid}) =>
      _user(patientUid).collection('family').doc(myUid).snapshots().map((d) => d.data()?['status'] as String?);

  /// Stop looking after someone (both entries are removed).
  Future<void> leave({required String patientUid, required String myUid}) => _guard(() async {
        try {
          await _user(patientUid).collection('family').doc(myUid).delete();
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied' && e.code != 'not-found') rethrow; // already removed
        }
        await _user(myUid).collection('caring').doc(patientUid).delete();
      });

  /// Stops looking after everyone (account deletion).
  Future<void> leaveAll(String myUid) => _guard(() async {
        final caring = await _user(myUid).collection('caring').get();
        for (final d in caring.docs) {
          await leave(patientUid: d.id, myUid: myUid);
        }
      });

  Stream<List<Medicine>> watchMedicines(String patientUid) =>
      _user(patientUid).collection(kSyncedCollections['medicines']!).snapshots().map((s) => [
            for (final d in s.docs)
              if (d.data()[kDeletedFlag] != true) Medicine.fromJson(d.data()),
          ]);

  /// Dose logs from the last [days] days.
  Stream<List<DoseLog>> watchDoseLogs(String patientUid, {int days = 8}) {
    final since = dateKey(DateTime.now().subtract(Duration(days: days)));
    return _user(patientUid)
        .collection(kSyncedCollections['dose_logs']!)
        .where('scheduledDate', isGreaterThanOrEqualTo: since)
        .snapshots()
        .map((s) => [
              for (final d in s.docs)
                if (d.data()[kDeletedFlag] != true) DoseLog.fromJson(d.data()),
            ]);
  }

  /// Sends a reminder: stored for the person's app (shown when it runs or next opens) and,
  /// via the server, pushed as a notification to their phone right away. Returns false if
  /// only the in-app copy could be delivered (the push failed).
  Future<bool> sendReminder({
    required String patientUid,
    required String myUid,
    required String myName,
    required String message,
  }) async {
    await _guard(() => _user(patientUid).collection('nudges').add({
          'fromUid': myUid,
          'fromName': myName,
          'message': message,
          'sentAt': Timestamp.now(),
        }));
    try {
      final token = await idToken?.call();
      if (token == null) return false;
      final res = await http
          .post(
            Uri.parse('${SubscriptionService.baseUrl}/family/remind'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({'patientUid': patientUid, 'message': message}),
          )
          .timeout(const Duration(seconds: 20));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[Family] push failed: $e');
      return false;
    }
  }

  // ---------- Push notification tokens ----------

  Future<void> saveDeviceToken({required String myUid, required String token}) =>
      _user(myUid).collection('devices').doc(token).set({
        'platform': defaultTargetPlatform.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> removeDeviceToken({required String myUid, required String token}) =>
      _user(myUid).collection('devices').doc(token).delete();
}
