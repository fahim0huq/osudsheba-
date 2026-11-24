import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:appspro_sdk/appspro_sdk.dart';
import '../models/subscription.dart';

class SubscriptionService {
  /// Base URL of the OsudSheba backend
  static const String defaultProductionUrl = 'https://osudsheba.onrender.com';

  static String get baseUrl {
    const customUrl = String.fromEnvironment('BACKEND_BASE_URL');
    if (customUrl.isNotEmpty) {
      return customUrl;
    }
    return defaultProductionUrl;
  }

  /// Initialize AppsProClient with backend proxy for native SDK widgets
  static void configureNativeSdk({String? publishableKey, Future<String?> Function()? idTokenProvider}) {
    try {
      const defaultPublishableKey = String.fromEnvironment(
        'APPSPRO_PUBLISHABLE_KEY',
        defaultValue: 'pk_682ba67415f120b667de6f1a',
      );
      final key = publishableKey ?? defaultPublishableKey;
      AppsProClient.configure(
        publishableKey: key,
        backend: AppsProProxyBackend(
          baseUrl: baseUrl,
          paths: const AppsProProxyPaths(
            appInfo: '/subscription/app-info',
            otpRequest: '/subscription/otp/request',
            otpVerify: '/subscription/otp/verify',
            subscription: '/subscription/status',
            unsubscribe: '/subscription/unsubscribe',
          ),
          headers: () async {
            if (idTokenProvider != null) {
              final token = await idTokenProvider();
              if (token != null) {
                return {'Authorization': 'Bearer $token'};
              }
            }
            return {};
          },
        ),
      );
      debugPrint('[SubscriptionService] AppsProClient configured with backend proxy');
    } catch (e) {
      debugPrint('[SubscriptionService] AppsProClient configure notice: $e');
    }
  }

  Map<String, String> _headers(String? idToken) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (idToken != null) 'Authorization': 'Bearer $idToken',
    };
  }

  /// Check current user subscription entitlement
  Future<Subscription> getStatus(String? idToken) async {
    final uri = Uri.parse('$baseUrl/subscription/status');
    try {
      final response = await http.get(uri, headers: _headers(idToken)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Subscription.fromJson(data);
      } else if (response.statusCode == 401) {
        return Subscription.unsubscribed();
      } else {
        final errorData = jsonDecode(response.body);
        return Subscription.error(errorData['message'] ?? 'Failed to check subscription status.');
      }
    } on SocketException {
      debugPrint('[SubscriptionService] Backend server unreachable at $baseUrl');
      return Subscription.error('Unable to connect to server. Please check your internet connection.');
    } catch (e) {
      debugPrint('[SubscriptionService] getStatus error: $e');
      return Subscription.error('Subscription check failed: $e');
    }
  }

  /// Fetch app pricing and metadata
  Future<AppPricingInfo> getAppInfo() async {
    final uri = Uri.parse('$baseUrl/subscription/app-info');
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AppPricingInfo.fromJson(data);
      }
    } catch (e) {
      debugPrint('[SubscriptionService] getAppInfo error: $e. Using fallback pricing.');
    }
    return AppPricingInfo.fallback;
  }

  /// Request OTP for subscription
  Future<Map<String, dynamic>> requestOtp(String phone, String? idToken) async {
    final uri = Uri.parse('$baseUrl/subscription/otp/request');
    final body = jsonEncode({'phone': phone});

    try {
      final response = await http.post(uri, headers: _headers(idToken), body: body).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && (data['success'] == true || data['reference_no'] != null)) {
        return data;
      } else {
        throw Exception(data['message'] ?? data['error'] ?? 'OTP request failed.');
      }
    } on SocketException {
      throw Exception('Cannot connect to subscription server. Check your connection.');
    }
  }

  /// Verify OTP and confirm subscription
  Future<Subscription> verifyOtp(String referenceNo, String otp, String? phone, String? idToken) async {
    final uri = Uri.parse('$baseUrl/subscription/otp/verify');
    final Map<String, dynamic> bodyMap = {
      'referenceNo': referenceNo,
      'reference_no': referenceNo,
      'otp': otp,
    };
    if (phone != null) {
      bodyMap['phone'] = phone;
    }
    final body = jsonEncode(bodyMap);

    try {
      final response = await http.post(uri, headers: _headers(idToken), body: body).timeout(const Duration(seconds: 20));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return Subscription.fromJson(data);
      } else {
        throw Exception(data['message'] ?? data['error'] ?? 'OTP verification failed.');
      }
    } on SocketException {
      throw Exception('Cannot connect to subscription server. Check your connection.');
    }
  }

  /// Cancel current active subscription
  Future<Subscription> unsubscribe(String? idToken) async {
    final uri = Uri.parse('$baseUrl/subscription/unsubscribe');
    try {
      final response = await http.post(uri, headers: _headers(idToken)).timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return Subscription.fromJson(data);
      } else {
        throw Exception(data['message'] ?? data['error'] ?? 'Failed to cancel subscription.');
      }
    } on SocketException {
      throw Exception('Cannot connect to subscription server. Check your connection.');
    }
  }

  /// Delete this user's data on the server (account deletion).
  /// Throws [SubscriptionStillActiveException] while carrier billing is still running.
  Future<void> deleteAccountData(String? idToken) async {
    final uri = Uri.parse('$baseUrl/subscription/account');
    try {
      final response = await http.delete(uri, headers: _headers(idToken)).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) return;
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}
      if (response.statusCode == 409 && data['error'] == 'SUBSCRIPTION_STILL_ACTIVE') {
        throw const SubscriptionStillActiveException();
      }
      if (response.statusCode == 502 && data['error'] == 'BILLING_DATA_DELETE_FAILED') {
        throw const BillingDataDeleteFailedException();
      }
      throw Exception(data['message'] ?? 'Could not delete your account data (HTTP ${response.statusCode}).');
    } on SocketException {
      throw Exception('Cannot connect to the server. Check your connection.');
    } on TimeoutException {
      throw Exception('The server did not answer. Please try again.');
    }
  }
}

/// The server refused to delete account data because the subscription is still active.
class SubscriptionStillActiveException implements Exception {
  const SubscriptionStillActiveException();
}

/// AppsPro could not remove the phone number from its subscriber record, so the server
/// deleted nothing. The user can try again later.
class BillingDataDeleteFailedException implements Exception {
  const BillingDataDeleteFailedException();
}
