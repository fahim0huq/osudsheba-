/**
 * Premium Subscription Enforcement Middleware
 * Verifies that the authenticated user holds an active or pending entitlement.
 */

const { SubscriptionService } = require('../services/subscription.service');

async function requireSubscription(req, res, next) {
  try {
    if (!req.user || !req.user.uid) {
      return res.status(401).json({
        success: false,
        error: 'AUTH_REQUIRED',
        message: 'Authentication is required before checking subscription entitlement.',
      });
    }

    const uid = req.user.uid;
    const subscription = await SubscriptionService.getSubscription(uid);

    if (!subscription || !subscription.entitlementActive) {
      const status = subscription ? subscription.status : 'not_subscribed';
      console.warn(`[requireSubscription] Access denied for user ${uid}. Status: ${status}`);
      return res.status(403).json({
        success: false,
        error: 'SUBSCRIPTION_REQUIRED',
        message: 'An active OsudSheba subscription is required to access this feature.',
        status: status,
      });
    }

    // Attach verified subscription record to request
    req.subscription = subscription;
    next();
  } catch (err) {
    console.error('[requireSubscription] Error checking subscription:', err.message);
    return res.status(500).json({
      success: false,
      error: 'SUBSCRIPTION_CHECK_FAILED',
      message: 'Failed to verify subscription status. Please try again later.',
    });
  }
}

module.exports = {
  requireSubscription,
};
