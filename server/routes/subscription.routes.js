/**
 * Subscription Routes
 * Defines endpoints for subscription status, OTP management, app metadata, and cancellation.
 */

const express = require('express');
const rateLimit = require('express-rate-limit');
const { authenticateFirebaseToken } = require('../middleware/auth.middleware');
const { SubscriptionController } = require('../controllers/subscription.controller');

const router = express.Router();

// Rate limiter for OTP requests (prevents SMS spamming)
const otpRequestLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutes
  max: 6, // max 6 OTP requests per 10 minutes
  keyGenerator: (req) => req.user ? req.user.uid : req.ip,
  validate: false,
  message: {
    success: false,
    error: 'RATE_LIMITED',
    message: 'Too many OTP requests. Please wait a few minutes before trying again.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Authenticated subscription endpoints
router.get('/status', authenticateFirebaseToken, SubscriptionController.getStatus);
router.get('/subscription', authenticateFirebaseToken, SubscriptionController.getStatus); // Proxy compatibility
router.get('/app-info', SubscriptionController.getAppInfo);
// Operator-only diagnostics. Disabled unless DIAGNOSTICS_TOKEN is configured, and then
// requires header "x-diagnostics-token: <DIAGNOSTICS_TOKEN>". Never public.
router.get('/diagnostic', async (req, res) => {
  const expected = (process.env.DIAGNOSTICS_TOKEN || '').trim();
  const provided = String(req.headers['x-diagnostics-token'] || '');
  const crypto = require('crypto');
  const ok = expected.length >= 16 && provided.length === expected.length &&
    crypto.timingSafeEqual(Buffer.from(provided), Buffer.from(expected));
  if (!ok) {
    return res.status(404).json({ success: false, error: 'NOT_FOUND' });
  }
  try {
    const { AppsProService } = require('../services/appspro.service');
    const diagnostic = await AppsProService.runDiagnostics();
    return res.status(200).json({ success: true, ...diagnostic });
  } catch (err) {
    return res.status(500).json({ success: false, error: err.message });
  }
});
router.post('/otp/request', authenticateFirebaseToken, otpRequestLimiter, SubscriptionController.requestOtp);
router.post('/otp/verify', authenticateFirebaseToken, SubscriptionController.verifyOtp);
router.post('/unsubscribe', authenticateFirebaseToken, SubscriptionController.unsubscribe);
router.post('/subscribe', authenticateFirebaseToken, SubscriptionController.directSubscribe);
router.delete('/account', authenticateFirebaseToken, SubscriptionController.deleteAccountData);

module.exports = router;
