// Helpers for SMS reminders a caregiver sends from their own phone and SIM.

const _bnToEn = {'০': '0', '১': '1', '২': '2', '৩': '3', '৪': '4', '৫': '5', '৬': '6', '৭': '7', '৮': '8', '৯': '9'};

/// A Bangladeshi mobile number as "01XXXXXXXXX", or null if [raw] is not one.
/// Accepts spaces, dashes, Bangla digits and a +880 / 880 prefix.
String? normalizeBdMobile(String raw) {
  var d = raw.trim().split('').map((c) => _bnToEn[c] ?? c).join();
  d = d.replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.startsWith('+880')) {
    d = d.substring(3);
  } else if (d.startsWith('880')) {
    d = d.substring(2);
  }
  return RegExp(r'^01[3-9][0-9]{8}$').hasMatch(d) ? d : null;
}

/// The SMS text: the app name, the reminder, and who sent it, so the person knows it is
/// from family and not from an unknown number.
String caregiverSmsBody({required String message, required String fromName, required bool bn}) {
  final name = fromName.trim();
  if (bn) return name.isEmpty ? 'ওষুধসেবা: $message' : 'ওষুধসেবা: $message — $name';
  return name.isEmpty ? 'OsudSheba: $message' : 'OsudSheba: $message - $name';
}
