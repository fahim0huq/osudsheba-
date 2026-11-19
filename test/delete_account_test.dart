// Account deletion must stop carrier billing BEFORE anything is deleted, and must not
// delete the account if the operator does not confirm the cancellation.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:osudsheba/core/constants/app_features.dart';
import 'package:osudsheba/core/models/auth_user.dart';
import 'package:osudsheba/core/models/subscription.dart';
import 'package:osudsheba/core/providers/subscription_provider.dart';
import 'package:osudsheba/core/services/auth_service.dart';
import 'package:osudsheba/core/services/mock_data_service.dart';
import 'package:osudsheba/core/services/subscription_service.dart';
import 'package:osudsheba/features/settings/presentation/delete_account_tile.dart';

/// Each test uses its own user id, so its Hive cache box is not shared with another test.
var _nextUid = 0;

class _FakeAuth implements AuthService {
  @override
  Future<void> sendPasswordReset(String email) async {}

  _FakeAuth(this.calls) : _user = AuthUser(uid: 'u${++_nextUid}', email: 'a@example.com');
  final List<String> calls;
  final AuthUser _user;

  @override
  AuthUser? get currentUser => _user;
  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(_user);
  @override
  Future<String?> getIdToken() async => 'token';
  @override
  String? get signInMethod => 'password';
  @override
  bool get hasRecentSignIn => true;
  @override
  Future<void> deleteCurrentUser() async => calls.add('deleteUser');
  @override
  Future<void> reauthenticateWithPassword(String password) async {}
  @override
  Future<void> reauthenticateWithGoogle() async {}
  @override
  Future<void> signInWithEmail(String email, String password) async {}
  @override
  Future<void> signUpWithEmail(String email, String password) async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> sendPhoneVerification(String phone) async {}
  @override
  Future<void> verifyPhoneOtp(String otp) async {}
  @override
  Future<void> signOut() async {}
}

/// Server fake: the first delete is refused while [subscribed]; unsubscribe clears it.
class _FakeServer extends SubscriptionService {
  _FakeServer(this.calls, {required this.subscribed, this.operatorFails = false});
  final List<String> calls;
  bool subscribed;
  final bool operatorFails;

  @override
  Future<Subscription> getStatus(String? idToken) async => Subscription.unsubscribed();

  @override
  Future<Subscription> unsubscribe(String? idToken) async {
    calls.add('unsubscribe');
    if (operatorFails) throw Exception('Operator did not confirm the cancellation.');
    subscribed = false;
    return Subscription.unsubscribed();
  }

  @override
  Future<void> deleteAccountData(String? idToken) async {
    calls.add('deleteServerData');
    if (subscribed) throw const SubscriptionStillActiveException();
  }
}

Future<void> _runDeletion(WidgetTester tester, AuthService auth, SubscriptionService server) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const Scaffold(body: DeleteAccountTile())),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      subscriptionServiceProvider.overrideWithValue(server),
      userUidProvider.overrideWithValue(auth.currentUser!.uid),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  await tester.tap(find.text('Delete my account'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Yes, delete my account'));
  // The subscription cache is written with real file I/O (Hive), which does not advance
  // under the test's fake clock, so let real time pass between frames.
  // Wait until the flow has finished one way or the other (max ~10 s).
  bool finished() =>
      find.text('Your account has been deleted.').evaluate().isNotEmpty ||
      find.text('Account not deleted').evaluate().isNotEmpty;
  for (var i = 0; i < 100 && !finished(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finished(), isTrue, reason: 'deletion flow did not finish');
}

void main() {
  setUpAll(() {
    Hive.init(Directory.systemTemp.createTempSync('delete_account_test').path);
  });

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (_) async => null,
    );
  });

  testWidgets('active subscription is cancelled before the account is deleted', (tester) async {
    final calls = <String>[];
    await _runDeletion(tester, _FakeAuth(calls), _FakeServer(calls, subscribed: true));
    expect(calls, ['deleteServerData', 'unsubscribe', 'deleteServerData', 'deleteUser']);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
  });

  testWidgets('if the operator does not confirm the cancellation, nothing is deleted', (tester) async {
    final calls = <String>[];
    await _runDeletion(tester, _FakeAuth(calls), _FakeServer(calls, subscribed: true, operatorFails: true));
    expect(calls, ['deleteServerData', 'unsubscribe']);
    expect(calls, isNot(contains('deleteUser')));
    expect(find.text('Account not deleted'), findsOneWidget);
  });

  testWidgets('without a subscription the account is deleted directly', (tester) async {
    final calls = <String>[];
    await _runDeletion(tester, _FakeAuth(calls), _FakeServer(calls, subscribed: false));
    expect(calls, ['deleteServerData', 'deleteUser']);
  });

  test('caregiver role is mapped to Patient while it is switched off', () {
    expect(kCaregiverRoleEnabled, isFalse);
    expect(effectiveRole('Caregiver'), 'Patient');
    expect(effectiveRole('Patient'), 'Patient');
    expect(effectiveRole('None'), 'None');
  });
}
