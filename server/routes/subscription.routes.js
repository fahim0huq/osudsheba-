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
router.post('/otp/request', authenticateFirebaseToken, otpRequestLimiter, SubscriptionController.requestOtp);
router.post('/otp/verify', authenticateFirebaseToken, SubscriptionController.verifyOtp);
router.post('/unsubscribe', authenticateFirebaseToken, SubscriptionController.unsubscribe);
router.post('/subscribe', authenticateFirebaseToken, SubscriptionController.directSubscribe);

module.exports = router;
