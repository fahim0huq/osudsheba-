class AuthUser {
  final String uid;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final String? photoUrl;

  const AuthUser({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.photoUrl,
  });

  @override
  String toString() {
    return 'AuthUser(uid: $uid, email: $email, phoneNumber: $phoneNumber, displayName: $displayName)';
  }
}
