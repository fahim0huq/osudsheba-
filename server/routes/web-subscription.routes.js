/**
 * Public Web Subscription Routes
 * Narrowly-scoped, strictly rate-limited endpoints for the OsudSheba website.
 * No user login, no passwords, and no Firebase authentication required.
 * Phone number + AppsPro carrier billing identity only.
 */

const express = require('express');
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const { AppsProService, maskPhone } = require('../services/appspro.service');
const { SubscriptionService } = require('../services/subscription.service');
const { normalizeBangladeshPhone } = require('../controllers/subscription.controller');

const router = express.Router();

// Signing secret for web download tokens
const TOKEN_SECRET = process.env.APPSPRO_SECRET_KEY || process.env.DOWNLOAD_TOKEN_SECRET || 'osudsheba_web_secure_token_secret_key_2026';

/**
 * Validate Bangladesh Robi and Airtel mobile operators
 * Robi prefix: 018...
 * Airtel prefix: 016...
 */
function isSupportedCarrier(normalizedPhone) {
  if (!normalizedPhone || typeof normalizedPhone !== 'string') return false;
  return normalizedPhone.startsWith('018') || normalizedPhone.startsWith('016');
}

/**
 * Generate HMAC-SHA256 signed download token
 */
function generateDownloadToken(phone) {
  const payload = {
    phone,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + (24 * 60 * 60), // 24-hour validity
  };
  const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = crypto.createHmac('sha256', TOKEN_SECRET).update(encodedPayload).digest('base64url');
  return `${encodedPayload}.${signature}`;
}

/**
 * Verify HMAC-SHA256 signed download token
 */
function verifyDownloadToken(token) {
  if (!token || typeof token !== 'string') return null;
  const parts = token.split('.');
  if (parts.length !== 2) return null;

  const [encodedPayload, signature] = parts;
  const expectedSignature = crypto.createHmac('sha256', TOKEN_SECRET).update(encodedPayload).digest('base64url');

  if (signature !== expectedSignature) return null;

  try {
    const payload = JSON.parse(Buffer.from(encodedPayload, 'base64url').toString('utf8'));
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) {
      return null; // Expired
    }
    return payload;
  } catch {
    return null;
  }
}

// 1. Rate limiter for OTP requests: max 5 requests per 10 minutes per IP
const webOtpRequestLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 5,
  validate: false,
  message: {
    success: false,
    error: 'RATE_LIMITED',
    message: 'Too many OTP requests. Please wait 10 minutes before requesting another code.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// 2. Rate limiter for OTP verification: max 10 verification attempts per 10 minutes
const webOtpVerifyLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 10,
  validate: false,
  message: {
    success: false,
    error: 'RATE_LIMITED',
    message: 'Too many verification attempts. Please wait 10 minutes before trying again.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// 3. Rate limiter for status queries: max 30 per 10 minutes
const webStatusLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 30,
  validate: false,
  message: {
    success: false,
    error: 'RATE_LIMITED',
    message: 'Too many status requests. Please wait a moment.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

/**
 * GET /web-subscription/app-info
 * Returns public pricing and carrier metadata
 */
router.get('/app-info', async (req, res) => {
  try {
    const appInfo = await AppsProService.getAppInfo();
    return res.status(200).json({
      success: true,
      name: appInfo.name || 'OsudSheba',
      pricing: appInfo.pricing || {
        amount: '2.00',
        currency: 'BDT',
        frequency: 'daily',
      },
      supported_carriers: ['Robi', 'Airtel'],
      carrier_billing_provider: 'AppsPro / BDApps',
    });
  } catch (err) {
    return res.status(200).json({
      success: true,
      name: 'OsudSheba',
      pricing: {
        amount: '2.00',
        currency: 'BDT',
        frequency: 'daily',
      },
      supported_carriers: ['Robi', 'Airtel'],
      carrier_billing_provider: 'AppsPro / BDApps',
    });
  }
});

/**
 * POST /web-subscription/otp/request
 * Initiates phone subscription via AppsPro
 */
router.post('/otp/request', webOtpRequestLimiter, async (req, res) => {
  try {
    const { phone } = req.body;
    if (!phone) {
      return res.status(400).json({
        success: false,
        error: 'PHONE_REQUIRED',
        message: 'Mobile phone number is required.',
      });
    }

    const normalizedPhone = normalizeBangladeshPhone(phone);
    if (!normalizedPhone) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_PHONE_FORMAT',
        message: 'Please enter a valid 11-digit Bangladeshi mobile number (e.g. 018XXXXXXXX).',
      });
    }

    if (!isSupportedCarrier(normalizedPhone)) {
      return res.status(400).json({
        success: false,
        error: 'UNSUPPORTED_OPERATOR',
        message: 'OsudSheba carrier billing currently supports Robi (018) and Airtel (016) numbers.',
      });
    }

    // Check if phone number is already actively subscribed in database
    const existingSub = await SubscriptionService.findSubscriptionByPhone(normalizedPhone);
    if (existingSub && existingSub.entitlementActive) {
      const downloadToken = generateDownloadToken(normalizedPhone);
      return res.status(200).json({
        success: true,
        alreadyRegistered: true,
        valid: true,
        status: 'active',
        phoneMasked: maskPhone(normalizedPhone),
        downloadToken,
        message: 'Your phone number is already registered with an active OsudSheba subscription!',
      });
    }

    // Call AppsPro to send OTP
    const externalUserId = `web_${normalizedPhone}`;
    const result = await AppsProService.requestOtp(normalizedPhone, externalUserId);

    if (result.alreadyRegistered || result.valid) {
      // Upstream already registered
      await SubscriptionService.saveSubscription(externalUserId, {
        status: 'active',
        phone: normalizedPhone,
      });
      const downloadToken = generateDownloadToken(normalizedPhone);
      return res.status(200).json({
        success: true,
        alreadyRegistered: true,
        valid: true,
        status: 'active',
        phoneMasked: maskPhone(normalizedPhone),
        downloadToken,
        message: 'Your phone number already has an active subscription!',
      });
    }

    const refNo = result.reference_no || result.referenceNo || result.ref_id || result.data?.reference_no;

    return res.status(200).json({
      success: true,
      reference_no: refNo,
      phoneMasked: maskPhone(normalizedPhone),
      message: 'OTP has been sent to your mobile phone.',
    });
  } catch (err) {
    console.error('[WebSubscription] requestOtp error:', err.message);
    const statusCode = err.status || 500;
    return res.status(statusCode).json({
      success: false,
      error: err.data?.error || 'OTP_REQUEST_FAILED',
      message: err.message || 'Failed to request OTP. Please try again.',
    });
  }
});

/**
 * POST /web-subscription/otp/verify
 * Verifies OTP code with AppsPro and confirms subscription
 */
router.post('/otp/verify', webOtpVerifyLimiter, async (req, res) => {
  try {
    const referenceNo = req.body.referenceNo || req.body.reference_no;
    const otp = req.body.otp;
    const phone = req.body.phone;

    if (!referenceNo || !otp) {
      return res.status(400).json({
        success: false,
        error: 'PARAMS_MISSING',
        message: 'Reference number and OTP code are required.',
      });
    }

    const cleanOtp = String(otp).trim();
    if (cleanOtp.length < 4 || cleanOtp.length > 8) {
      return res.status(400).json({
        success: false,
        error: 'INVALID_OTP_FORMAT',
        message: 'Please enter a valid OTP code.',
      });
    }

    const normalizedPhone = phone ? normalizeBangladeshPhone(phone) : null;
    const externalUserId = normalizedPhone ? `web_${normalizedPhone}` : `web_ref_${referenceNo}`;

    // Verify OTP with AppsPro
    const result = await AppsProService.verifyOtp(referenceNo, cleanOtp, externalUserId);

    const statusStr = result.subscription_status || result.status || (result.valid ? 'active' : 'unknown');
    const subscriberId = result.subscriber_id || result.subscriberId || result.data?.subscriber_id || null;
    const localSubscriberId = result.local_subscriber_id || result.id || null;
    const frequency = result.frequency || result.plan?.frequency || 'daily';
    const subscriberPhone = result.phone || normalizedPhone;

    const { entitlementActive: normalizedActive } = SubscriptionService.normalizeStatus(statusStr);
    const entitlementActive = normalizedActive || Boolean(result.valid);

    if (entitlementActive) {
      // Save subscription in database under externalUserId and subscriberPhone
      const savedRecord = await SubscriptionService.saveSubscription(externalUserId, {
        status: statusStr,
        appsproSubscriberId: subscriberId,
        appsproLocalSubscriberId: localSubscriberId,
        phone: subscriberPhone,
        frequency: frequency,
        isSandbox: process.env.APPSPRO_ENV === 'sandbox',
      });

      console.log(`[WebSubscription] Website subscription verified for ${maskPhone(subscriberPhone)}. Entitlement GRANTED.`);

      // Generate signed download token
      const downloadToken = generateDownloadToken(subscriberPhone || 'anonymous');

      return res.status(200).json({
        success: true,
        valid: true,
        status: savedRecord.status,
        entitlementActive: true,
        phoneMasked: savedRecord.phoneMasked || maskPhone(subscriberPhone),
        downloadToken,
        message: 'Subscription confirmed successfully! Your OsudSheba Premium subscription is active.',
      });
    } else {
      console.warn(`[WebSubscription] OTP verified but status not active: ${statusStr}`);
      return res.status(400).json({
        success: false,
        valid: false,
        status: statusStr,
        error: 'SUBSCRIPTION_NOT_ACTIVE',
        message: 'Subscription could not be confirmed. Please check with your mobile operator.',
      });
    }
  } catch (err) {
    console.error('[WebSubscription] verifyOtp error:', err.message);
    const statusCode = err.status || 400;
    return res.status(statusCode).json({
      success: false,
      error: err.data?.error || 'OTP_VERIFICATION_FAILED',
      message: err.message || 'OTP verification failed. Please check the code and try again.',
    });
  }
});

/**
 * POST /web-subscription/status
 * Queries subscription entitlement by phone or download token
 */
router.post('/status', webStatusLimiter, async (req, res) => {
  try {
    const { phone, downloadToken } = req.body;

    // 1. Try downloadToken verification
    if (downloadToken) {
      const payload = verifyDownloadToken(downloadToken);
      if (payload && payload.phone) {
        const sub = await SubscriptionService.findSubscriptionByPhone(payload.phone);
        if (sub && sub.entitlementActive) {
          return res.status(200).json({
            success: true,
            valid: true,
            status: sub.status,
            phoneMasked: sub.phoneMasked || maskPhone(payload.phone),
            subscribedAt: sub.subscribedAt,
          });
        }
      }
    }

    // 2. Try phone verification
    if (phone) {
      const normalizedPhone = normalizeBangladeshPhone(phone);
      if (normalizedPhone) {
        const sub = await SubscriptionService.findSubscriptionByPhone(normalizedPhone);
        if (sub) {
          return res.status(200).json({
            success: true,
            valid: sub.entitlementActive,
            status: sub.status,
            phoneMasked: sub.phoneMasked,
            subscribedAt: sub.subscribedAt,
          });
        }
      }
    }

    return res.status(200).json({
      success: true,
      valid: false,
      status: 'not_subscribed',
      phoneMasked: null,
    });
  } catch (err) {
    console.error('[WebSubscription] status error:', err.message);
    return res.status(500).json({
      success: false,
      error: 'STATUS_CHECK_FAILED',
      message: 'Could not retrieve subscription status.',
    });
  }
});

/**
 * GET /web-subscription/download-check
 * Verifies entitlement for downloading the OsudSheba application
 */
router.get('/download-check', async (req, res) => {
  try {
    const token = req.query.token || req.headers['x-download-token'];
    const phone = req.query.phone;

    let isAuthorized = false;

    if (token) {
      const payload = verifyDownloadToken(token);
      if (payload) {
        isAuthorized = true;
      }
    } else if (phone) {
      const normalizedPhone = normalizeBangladeshPhone(phone);
      if (normalizedPhone) {
        const sub = await SubscriptionService.findSubscriptionByPhone(normalizedPhone);
        if (sub && sub.entitlementActive) {
          isAuthorized = true;
        }
      }
    }

    if (!isAuthorized) {
      return res.status(403).json({
        success: false,
        error: 'SUBSCRIPTION_REQUIRED',
        message: 'Active subscription required to download OsudSheba.',
      });
    }

    const downloadUrl = process.env.ANDROID_DOWNLOAD_URL || process.env.NEXT_PUBLIC_ANDROID_DOWNLOAD_URL || '/downloads/osudsheba.apk';

    return res.status(200).json({
      success: true,
      downloadUrl,
      fileName: 'osudsheba.apk',
      message: 'Subscription verified. Download authorized.',
    });
  } catch (err) {
    return res.status(500).json({
      success: false,
      error: 'DOWNLOAD_CHECK_FAILED',
      message: 'Could not verify download authorization.',
    });
  }
});

module.exports = {
  webSubscriptionRouter: router,
  isSupportedCarrier,
  generateDownloadToken,
  verifyDownloadToken,
};
