import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/auth_user.dart';

abstract class AuthService {
  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> sendPhoneVerification(String phone);
  Future<void> verifyPhoneOtp(String otp);
  Future<void> signOut();

  /// Emails a password-reset link. Firebase does not reveal whether the email has an
  /// account, so a success only means the request was accepted.
  Future<void> sendPasswordReset(String email);
  Stream<AuthUser?> get authStateChanges;
  AuthUser? get currentUser;
  Future<String?> getIdToken();

  /// How the current user signs in: 'password', 'google.com', 'phone', or null.
  String? get signInMethod;

  /// Firebase only allows deleting an account shortly after signing in.
  bool get hasRecentSignIn;
  Future<void> reauthenticateWithPassword(String password);
  Future<void> reauthenticateWithGoogle();

  /// Permanently deletes the signed-in account.
  /// Throws [RecentSignInRequiredException] if the user must sign in again first.
  Future<void> deleteCurrentUser();
}

/// Firebase refused an account change because the last sign-in is too old.
class RecentSignInRequiredException implements Exception {
  const RecentSignInRequiredException();

  @override
  String toString() => 'Exception: Please sign in again, then try once more.';
}

class FirebaseAuthService implements AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  
  String? _verificationId;

  AuthUser? _mapFirebaseUser(User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email,
      phoneNumber: user.phoneNumber,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  @override
  AuthUser? get currentUser => _mapFirebaseUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges => 
      _firebaseAuth.authStateChanges().map(_mapFirebaseUser);

  @override
  Future<void> signInWithEmail(String email, String password) async {
    try {
      if (!email.contains('@') || email.length < 5) {
        throw Exception('Invalid email address format');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw _wrapError(e);
    }
  }

  @override
  Future<void> signUpWithEmail(String email, String password) async {
    try {
      if (!email.contains('@') || email.length < 5) {
        throw Exception('Invalid email address format');
      }
      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw _wrapError(e);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      throw _wrapError(e);
    }
  }

  @override
  Future<void> sendPhoneVerification(String phone) async {
    try {
      // Clean and normalize phone number (keep only digits)
      String digits = phone.replaceAll(RegExp(r'\D'), '');
      
      // Strip leading country code if present
      if (digits.startsWith('880')) {
        digits = digits.substring(3);
      } else if (digits.startsWith('0')) {
        digits = digits.substring(1);
      }

      // Bangladesh mobile number is exactly 11 digits (including leading 0),
      // which is 10 digits after stripping the leading 0 or 880.
      if (digits.length != 10 || (!digits.startsWith('18') && !digits.startsWith('16'))) {
        throw Exception('Only Robi and Airtel numbers are supported.');
      }

      final formattedPhone = '+880$digits';

      final completer = Completer<void>();

      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await _firebaseAuth.signInWithCredential(credential);
            if (!completer.isCompleted) {
              completer.complete();
            }
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(_wrapError(e));
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(_wrapError(e));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );

      return completer.future;
    } catch (e) {
      throw _wrapError(e);
    }
  }

  @override
  Future<void> verifyPhoneOtp(String otp) async {
    try {
      if (_verificationId == null) {
        throw Exception('Verification ID is not set. Please send verification code first.');
      }
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await _firebaseAuth.signInWithCredential(credential);
    } catch (e) {
      throw _wrapError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      throw _wrapError(e);
    }
  }

  @override
  Future<String?> getIdToken() async {
    try {
      return await _firebaseAuth.currentUser?.getIdToken();
    } catch (e) {
      throw _wrapError(e);
    }
  }

  @override
  String? get signInMethod {
    final providers = _firebaseAuth.currentUser?.providerData.map((p) => p.providerId).toList() ?? [];
    for (final id in const ['password', 'google.com', 'phone']) {
      if (providers.contains(id)) return id;
    }
    return null;
  }

  @override
  bool get hasRecentSignIn {
    final last = _firebaseAuth.currentUser?.metadata.lastSignInTime;
    // Firebase's own limit is about 5 minutes; stay a little inside it.
    return last != null && DateTime.now().difference(last) < const Duration(minutes: 4);
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) throw Exception('Not signed in.');
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } catch (e) {
      throw _wrapError(e);
    }
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) throw Exception('Not signed in.');
    try {
      final googleUser = await _googleSignIn.authenticate();
      final credential = GoogleAuthProvider.credential(idToken: googleUser.authentication.idToken);
      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      throw _wrapError(e);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw _wrapError(e);
    }
  }

  @override
  Future<void> deleteCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') throw const RecentSignInRequiredException();
      throw _wrapError(e);
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Exception _wrapError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return Exception('wrong-password or user-not-found: Incorrect email or password.');
        case 'email-already-in-use':
          return Exception('The email address is already in use by another account.');
        case 'invalid-email':
          return Exception('Invalid email address format.');
        case 'weak-password':
          return Exception('Password must be at least 6 characters.');
        case 'network-request-failed':
          return Exception('Network error occurred. Please check your connection.');
        case 'invalid-verification-code':
          return Exception('Invalid OTP verification code.');
        case 'invalid-phone-number':
          return Exception('Invalid phone number format.');
        case 'too-many-requests':
          return Exception('Too many requests. Please try again later.');
        case 'user-disabled':
          return Exception('This user account has been disabled.');
        case 'operation-not-allowed':
          return Exception('This authentication method is not enabled.');
        default:
          return Exception(e.message ?? e.toString());
      }
    }
    return e is Exception ? e : Exception(e.toString());
  }
}

// Riverpod Providers
final authServiceProvider = Provider<AuthService>((ref) {
  return FirebaseAuthService();
});

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});
