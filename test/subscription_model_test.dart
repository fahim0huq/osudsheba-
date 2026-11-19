import 'package:flutter_test/flutter_test.dart';
import 'package:osudsheba/core/models/subscription.dart';

void main() {
  group('Payment Safety & Subscription Model Tests', () {
    test('Zero-balance / pending subscription must NOT grant premium entitlement', () {
      const subPending = Subscription(
        status: 'pending',
        entitlementActive: false,
      );
      expect(subPending.isEntitled, isFalse);
      expect(subPending.isPending, isTrue);
      expect(subPending.isActive, isFalse);
    });

    test('Pending status must remain unentitled even if entitlementActive flag is erroneously true', () {
      const subPendingGlitch = Subscription(
        status: 'pending',
        entitlementActive: true,
      );
      // Status is 'pending', not 'active' -> must NOT unlock app
      expect(subPendingGlitch.isEntitled, isFalse);
    });

    test('INITIAL CHARGING PENDING must NOT unlock app', () {
      const subInitialChargingPending = Subscription(
        status: 'INITIAL CHARGING PENDING',
        entitlementActive: false,
      );
      expect(subInitialChargingPending.isEntitled, isFalse);
      expect(subInitialChargingPending.isPending, isTrue);
      expect(subInitialChargingPending.isActive, isFalse);
    });

    test('Unsubscribed or cancelled user must NOT unlock app', () {
      final unSub = Subscription.unsubscribed();
      expect(unSub.isEntitled, isFalse);
      expect(unSub.isActive, isFalse);

      const cancelledSub = Subscription(
        status: 'cancelled',
        entitlementActive: false,
      );
      expect(cancelledSub.isEntitled, isFalse);
      expect(cancelledSub.isCancelled, isTrue);
    });

    test('Genuinely active and paid subscription MUST unlock app', () {
      const activeSub = Subscription(
        status: 'active',
        entitlementActive: true,
        frequency: 'daily',
      );
      expect(activeSub.isEntitled, isTrue);
      expect(activeSub.isActive, isTrue);
      expect(activeSub.isPending, isFalse);
    });

    test('Active status with entitlementActive false must NOT unlock app', () {
      const activeWithoutEntitlement = Subscription(
        status: 'active',
        entitlementActive: false,
      );
      expect(activeWithoutEntitlement.isEntitled, isFalse);
    });

    test('JSON deserialization parses pending response as unentitled', () {
      final jsonPending = {
        'success': true,
        'valid': true,
        'isSubscribed': false,
        'status': 'pending',
        'entitlementActive': false,
        'subscription': {
          'status': 'pending',
          'entitlementActive': false,
          'frequency': 'daily',
        },
      };

      final sub = Subscription.fromJson(jsonPending);
      expect(sub.isEntitled, isFalse);
      expect(sub.isPending, isTrue);
      expect(sub.entitlementActive, isFalse);
      expect(sub.status, 'pending');
    });

    test('JSON deserialization parses active paid response as entitled', () {
      final jsonActive = {
        'success': true,
        'valid': true,
        'isSubscribed': true,
        'status': 'active',
        'entitlementActive': true,
        'subscription': {
          'status': 'active',
          'entitlementActive': true,
          'frequency': 'daily',
        },
      };

      final sub = Subscription.fromJson(jsonActive);
      expect(sub.isEntitled, isTrue);
      expect(sub.isActive, isTrue);
      expect(sub.entitlementActive, isTrue);
      expect(sub.status, 'active');
    });
  });
}
