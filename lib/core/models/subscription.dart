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

  /// True only if user holds confirmed active entitlement and status is active
  bool get isEntitled => entitlementActive && (status.toLowerCase() == 'active' || status.toLowerCase() == 'registered');

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

/// Price shown on the subscription screen, read from AppsPro's `GET /api/v1/sdk/app-info`
/// (through our server's `/subscription/app-info`). That payload sends `pricing` as a list of
/// methods `{ method_name, display_name, price, price_inclusive, billing_period }` and a
/// BDApps-required price line in `disclosure_md` (https://appspro.dev/docs).
class AppPricingInfo {
  /// Base price, before VAT / SD / SC (AppsPro `price`).
  final String amount;

  /// Price with VAT, SD and SC added (AppsPro `price_inclusive`), when AppsPro sent it.
  final String? amountInclusive;
  final String currency;

  /// AppsPro `billing_period`, e.g. `daily`.
  final String frequency;
  final List<String> supportedCarriers;

  /// BDApps-required price disclosure (AppsPro `disclosure_md`), shown as plain text.
  final String? disclosure;

  /// True when the server could not reach AppsPro and sent its last known price.
  final bool isFallback;

  const AppPricingInfo({
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.supportedCarriers,
    this.amountInclusive,
    this.disclosure,
    this.isFallback = false,
  });

  factory AppPricingInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['pricing'];
    Map<String, dynamic> method = const {};
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      method = (raw.first as Map).cast<String, dynamic>();
    } else if (raw is Map) {
      // Older server builds sent { amount, currency, frequency }.
      final m = raw.cast<String, dynamic>();
      method = {'price': m['amount'], 'billing_period': m['frequency']};
    }
    final disclosure = (json['disclosure_md'] as String?)?.replaceAll(RegExp(r'[*_`#]'), '').trim();
    return AppPricingInfo(
      amount: _text(method['price']) ?? fallback.amount,
      amountInclusive: _text(method['price_inclusive']),
      currency: 'BDT',
      frequency: _text(method['billing_period']) ?? fallback.frequency,
      supportedCarriers: fallback.supportedCarriers,
      disclosure: (disclosure == null || disclosure.isEmpty) ? null : disclosure,
      isFallback: json['fallback'] == true,
    );
  }

  static String? _text(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty || s == 'null') ? null : s;
  }

  /// "দিন" / "day" for the billing period.
  String periodLabel(bool isBn) {
    switch (frequency.toLowerCase()) {
      case 'weekly':
        return isBn ? 'সপ্তাহ' : 'week';
      case 'monthly':
        return isBn ? 'মাস' : 'month';
      default:
        return isBn ? 'দিন' : 'day';
    }
  }

  /// The tax line under the price: the real total when AppsPro sent one.
  String taxLine(bool isBn) {
    final total = amountInclusive;
    if (total != null) {
      return isBn
          ? 'ভ্যাট, এসডি ও এসসি সহ মোট ৳$total / ${periodLabel(true)}'
          : 'Total with VAT, SD & SC: ৳$total / ${periodLabel(false)}';
    }
    return isBn ? '+ ভ্যাট, এসডি ও এসসি প্রযোজ্য' : '+ VAT, SD & SC applicable';
  }

  static const fallback = AppPricingInfo(
    amount: '2.00',
    currency: 'BDT',
    frequency: 'daily',
    supportedCarriers: ['Robi', 'Airtel'],
    isFallback: true,
  );
}
