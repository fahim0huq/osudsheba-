import 'package:flutter/foundation.dart';

enum SubscriptionState {
  loading,
  active,
  pending,
  notSubscribed,
  cancelled,
  inactive,
  unknown,
  error,
}

@immutable
class Subscription {
  final String status;
  final bool entitlementActive;
  final String? frequency;
  final String? phoneMasked;
  final DateTime? subscribedAt;
  final DateTime? cancelledAt;
  final DateTime? lastVerifiedAt;
  final String? subscriberId;
  final String? errorMessage;

  const Subscription({
    required this.status,
    required this.entitlementActive,
    this.frequency,
    this.phoneMasked,
    this.subscribedAt,
    this.cancelledAt,
    this.lastVerifiedAt,
    this.subscriberId,
    this.errorMessage,
  });

  /// True if user is granted premium access (active or pending per AppsPro rule)
  bool get isEntitled => entitlementActive || status == 'active' || status == 'pending' || status.toLowerCase().contains('pending');

  bool get isActive => status == 'active';
  bool get isPending => status == 'pending' || status.toLowerCase().contains('pending');
  bool get isCancelled => status == 'cancelled';
  bool get isNotSubscribed => status == 'not_subscribed' || status == 'unregistered';

  SubscriptionState get state {
    if (errorMessage != null) return SubscriptionState.error;
    final s = status.toLowerCase();
    if (s == 'active' || s == 'registered' || s == 'subscribed' || s == 'success') {
      return SubscriptionState.active;
    }
    if (s == 'pending' || s.contains('pending')) {
      return SubscriptionState.pending;
    }
    if (s == 'cancelled' || s == 'unregistered' || s == 'deactivated') {
      return SubscriptionState.cancelled;
    }
    if (s == 'inactive' || s == 'expired') {
      return SubscriptionState.inactive;
    }
    if (s == 'not_subscribed') {
      return SubscriptionState.notSubscribed;
    }
    return SubscriptionState.unknown;
  }

  factory Subscription.unsubscribed() {
    return const Subscription(
      status: 'not_subscribed',
      entitlementActive: false,
    );
  }

  factory Subscription.error(String message) {
    return Subscription(
      status: 'error',
      entitlementActive: false,
      errorMessage: message,
    );
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final subData = json['subscription'] is Map<String, dynamic> 
        ? json['subscription'] as Map<String, dynamic> 
        : json;

    final rawStatus = subData['status'] as String? ?? 'not_subscribed';
    final entitlementActive = subData['entitlementActive'] as bool? ?? 
        (rawStatus.toLowerCase() == 'active' || rawStatus.toLowerCase().contains('pending') || rawStatus.toLowerCase() == 'subscribed');

    return Subscription(
      status: rawStatus,
      entitlementActive: entitlementActive,
      frequency: subData['frequency'] as String? ?? 'daily',
      phoneMasked: subData['phoneMasked'] as String?,
      subscribedAt: parseDate(subData['subscribedAt']),
      cancelledAt: parseDate(subData['cancelledAt']),
      lastVerifiedAt: parseDate(subData['lastVerifiedAt']),
      subscriberId: subData['subscriberId'] as String?,
      errorMessage: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'entitlementActive': entitlementActive,
      'frequency': frequency,
      'phoneMasked': phoneMasked,
      'subscribedAt': subscribedAt?.toIso8601String(),
      'cancelledAt': cancelledAt?.toIso8601String(),
      'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
      'subscriberId': subscriberId,
      'errorMessage': errorMessage,
    };
  }

  Subscription copyWith({
    String? status,
    bool? entitlementActive,
    String? frequency,
    String? phoneMasked,
    DateTime? subscribedAt,
    DateTime? cancelledAt,
    DateTime? lastVerifiedAt,
    String? subscriberId,
    String? errorMessage,
  }) {
    return Subscription(
      status: status ?? this.status,
      entitlementActive: entitlementActive ?? this.entitlementActive,
      frequency: frequency ?? this.frequency,
      phoneMasked: phoneMasked ?? this.phoneMasked,
      subscribedAt: subscribedAt ?? this.subscribedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      subscriberId: subscriberId ?? this.subscriberId,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AppPricingInfo {
  final String amount;
  final String currency;
  final String frequency;
  final List<String> supportedCarriers;
  final String? vatSdText;

  const AppPricingInfo({
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.supportedCarriers,
    this.vatSdText,
  });

  factory AppPricingInfo.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] as Map<String, dynamic>? ?? {};
    final carriers = json['supported_carriers'] as List<dynamic>? ?? ['Robi', 'Airtel'];

    return AppPricingInfo(
      amount: pricing['amount']?.toString() ?? '2.00',
      currency: pricing['currency']?.toString() ?? 'BDT',
      frequency: pricing['frequency']?.toString() ?? 'daily',
      supportedCarriers: carriers.map((e) => e.toString()).toList(),
      vatSdText: '+ VAT, SD & SC applicable',
    );
  }

  static const fallback = AppPricingInfo(
    amount: '2.00',
    currency: 'BDT',
    frequency: 'daily',
    supportedCarriers: ['Robi', 'Airtel'],
    vatSdText: '+ ১৫% ভ্যাট, ১৫% এসডি ও ১% এসসি প্রযোজ্য',
  );
}
