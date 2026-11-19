import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/subscription.dart';
import '../models/auth_user.dart';
import '../services/subscription_service.dart';
import '../services/auth_service.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

final appPricingInfoProvider = FutureProvider<AppPricingInfo>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return service.getAppInfo();
});

class SubscriptionNotifier extends StateNotifier<AsyncValue<Subscription>> {
  final Ref _ref;
  final SubscriptionService _service;
  String? _currentUid;

  SubscriptionNotifier(this._ref, this._service) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    _ref.listen<AsyncValue<AuthUser?>>(authStateProvider, (previous, next) {
      next.whenData((authUser) {
        final newUid = authUser?.uid;
        if (newUid != _currentUid) {
          _currentUid = newUid;
          if (newUid != null) {
            _loadUserSubscription(newUid);
          } else {
            // User logged out: clear state completely
            state = AsyncValue.data(Subscription.unsubscribed());
          }
        }
      });
    });

    // Check initial user
    final currentAuthUser = _ref.read(authServiceProvider).currentUser;
    if (currentAuthUser != null) {
      _currentUid = currentAuthUser.uid;
      _loadUserSubscription(currentAuthUser.uid);
    } else {
      state = AsyncValue.data(Subscription.unsubscribed());
    }
  }

  Future<void> _loadUserSubscription(String uid) async {
    // 1. Check local Hive cache for smooth UX (prevents UI flicker)
    try {
      final boxName = 'subscription_cache_$uid';
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<Map>(boxName);
      }
      final box = Hive.box<Map>(boxName);
      final cachedMap = box.get('subscription');
      if (cachedMap != null) {
        final cachedSub = Subscription.fromJson(Map<String, dynamic>.from(cachedMap));
        state = AsyncValue.data(cachedSub);
      } else {
        state = const AsyncValue.loading();
      }
    } catch (_) {
      state = const AsyncValue.loading();
    }

    // 2. Fetch authoritative status from backend
    await refreshStatus();
  }

  Future<void> _cacheSubscription(String uid, Subscription sub) async {
    try {
      final boxName = 'subscription_cache_$uid';
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox<Map>(boxName);
      }
      final box = Hive.box<Map>(boxName);
      await box.put('subscription', sub.toJson());
    } catch (e) {
      debugPrint('[SubscriptionNotifier] Cache write notice: $e');
    }
  }

  Future<void> _clearCache(String uid) async {
    try {
      final boxName = 'subscription_cache_$uid';
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<Map>(boxName).clear();
      }
    } catch (_) {}
  }

  /// Refresh subscription status from backend
  Future<void> refreshStatus() async {
    final uid = _currentUid;
    if (uid == null) {
      state = AsyncValue.data(Subscription.unsubscribed());
      return;
    }

    try {
      final idToken = await _ref.read(authServiceProvider).getIdToken();
      final freshSub = await _service.getStatus(idToken);

      // getStatus() reports network/server failures as an "error" subscription instead of
      // throwing. That is NOT an answer from the server about the user's subscription, so it
      // must never replace a known-good cached entitlement: otherwise a patient with no
      // internet (or while the server is waking up) is locked out of their medicine list
      // and reminders. Only an authoritative server answer may revoke access.
      final previous = state.value;
      if (freshSub.state == SubscriptionState.error && previous != null && previous.isEntitled) {
        debugPrint('[SubscriptionNotifier] Status check failed (${freshSub.errorMessage}); keeping cached entitlement.');
        return;
      }

      state = AsyncValue.data(freshSub);
      if (freshSub.state != SubscriptionState.error) {
        await _cacheSubscription(uid, freshSub);
      }
    } catch (e, st) {
      debugPrint('[SubscriptionNotifier] Refresh error: $e');
      // Keep a cached entitled state on unexpected errors too (offline-first).
      if (state.value == null || !state.value!.isEntitled) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Request OTP
  Future<String> requestOtp(String phone) async {
    final idToken = await _ref.read(authServiceProvider).getIdToken();
    final response = await _service.requestOtp(phone, idToken);
    if (response['alreadyRegistered'] == true || response['entitlementActive'] == true) {
      await refreshStatus();
      return 'ALREADY_REGISTERED';
    }
    final refNo = response['reference_no'] ?? response['referenceNo'] ?? '';
    return refNo.toString();
  }

  /// Verify OTP and immediately grant entitlement
  Future<bool> verifyOtp(String referenceNo, String otp, {String? phone}) async {
    final uid = _currentUid;
    final idToken = await _ref.read(authServiceProvider).getIdToken();
    
    state = const AsyncValue.loading();

    try {
      final verifiedSub = await _service.verifyOtp(referenceNo, otp, phone, idToken);
      state = AsyncValue.data(verifiedSub);

      if (uid != null) {
        await _cacheSubscription(uid, verifiedSub);
      }
      return verifiedSub.isEntitled;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Cancel subscription.
  ///
  /// Throws if the server/operator did not confirm the cancellation. Previously a failure was
  /// shown as "cancelled successfully" while the carrier kept charging the user every day.
  Future<void> unsubscribe() async {
    final uid = _currentUid;
    final idToken = await _ref.read(authServiceProvider).getIdToken();

    final cancelledSub = await _service.unsubscribe(idToken);
    state = AsyncValue.data(cancelledSub);
    if (uid != null) {
      await _cacheSubscription(uid, cancelledSub);
    }
  }

  /// Reset provider state upon logout
  Future<void> clear() async {
    final uid = _currentUid;
    if (uid != null) {
      await _clearCache(uid);
    }
    _currentUid = null;
    state = AsyncValue.data(Subscription.unsubscribed());
  }
}

final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, AsyncValue<Subscription>>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return SubscriptionNotifier(ref, service);
});

/// Convenience provider returning whether current user is entitled
final isEntitledProvider = Provider<bool>((ref) {
  final subAsync = ref.watch(subscriptionProvider);
  return subAsync.value?.isEntitled ?? false;
});
