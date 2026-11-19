import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

/// Opens the phone's own dialer or SMS app.
///
/// The dialer is opened with the number filled in; the user still presses the call button
/// there. This needs no CALL_PHONE permission and never places a call silently.
class PhoneActions {
  PhoneActions._();

  /// Keeps digits and a leading "+"; returns null if nothing dialable remains.
  static String? cleanNumber(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 3) return null;
    return trimmed.startsWith('+') ? '+$digits' : digits;
  }

  static Future<void> call(BuildContext context, String? number, {required String lang}) async {
    final clean = cleanNumber(number);
    if (clean == null) {
      _show(context, lang == 'bn' ? 'কোনো ফোন নম্বর সংরক্ষণ করা নেই। প্রোফাইলে নম্বর যোগ করুন।' : 'No phone number saved. Add one in the profile first.');
      return;
    }
    final ok = await _launch(Uri(scheme: 'tel', path: clean));
    if (!ok && context.mounted) {
      _show(context, lang == 'bn' ? 'এই ফোনে ডায়ালার খোলা যায়নি। নম্বর: $clean' : 'Could not open the phone dialer. Number: $clean');
    }
  }

  static Future<void> sms(BuildContext context, String? number, String body, {required String lang}) async {
    final clean = cleanNumber(number);
    if (clean == null) {
      _show(context, lang == 'bn' ? 'সঠিক ফোন নম্বর দিন।' : 'Please enter a valid phone number.');
      return;
    }
    // Encode manually: queryParameters would turn spaces into '+' in many SMS apps.
    final ok = await _launch(Uri(scheme: 'sms', path: clean, query: 'body=${Uri.encodeComponent(body)}'));
    if (!ok && context.mounted) {
      _show(context, lang == 'bn' ? 'এই ফোনে মেসেজ অ্যাপ খোলা যায়নি।' : 'Could not open the messaging app on this phone.');
    }
  }

  /// Opens the messaging app with [body] filled in and no recipient, so the user picks who.
  static Future<void> shareBySms(BuildContext context, String body, {required String lang}) async {
    final ok = await _launch(Uri(scheme: 'sms', path: '', query: 'body=${Uri.encodeComponent(body)}'));
    if (!ok && context.mounted) {
      _show(context, lang == 'bn' ? 'এই ফোনে মেসেজ অ্যাপ খোলা যায়নি।' : 'Could not open the messaging app on this phone.');
    }
  }

  static Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static void _show(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }
}
