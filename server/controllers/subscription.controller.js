/**
 * Subscription Controller
 * Handles user subscription operations, OTP flow, status queries, and cancellation.
 */

const { AppsProService, maskPhone } = require('../services/appspro.service');
const { SubscriptionService } = require('../services/subscription.service');

/**
 * Validate and normalize Bangladesh phone numbers.
 * Accepts: 01XXXXXXXXX, 8801XXXXXXXXX, +8801XXXXXXXXX
 */
function normalizeBangladeshPhone(phone) {
  if (!phone || typeof phone !== 'string') return null;
  let digits = phone.replace(/\D/g, '');

  if (digits.startsWith('880')) {
    digits = digits.substring(2); // keep 01XXXXXXXXX
  } else if (!digits.startsWith('0') && digits.length === 10) {
    digits = `0${digits}`;
  }

  // Must be 11 digits starting with 01
  if (digits.length === 11 && digits.startsWith('01')) {
    return digits;
  }
  return null;
}

/** The signed-in user's phone number as verified by Firebase phone sign-in, or null. */
function verifiedPhone(req) {
  return normalizeBangladeshPhone(req.user?.phone_number || req.user?.phoneNumber || '');
}

/** "tel:8801712345678" -> "01712345678" (BDApps ids can also be masked; then null). */
function phoneFromSubscriberId(subscriberId) {
  const m = /^tel:(?:\+?880)(1\d{9})$/.exec(String(subscriberId || ''));
  return m ? `0${m[1]}` : null;
}

/**
 * OTP references this server handed out, bound to the user who asked and the phone the OTP
 * went to. Verify uses this phone (never one sent by the app), so a subscription can only be
 * saved for, and later cancelled on, the number that received the OTP.
 */
const OTP_TTL_MS = 30 * 60 * 1000;
const pendingOtps = new Map();
function rememberOtp(referenceNo, uid, phone) {
  const now = Date.now();
  for (const [ref, v] of pendingOtps) if (v.expiresAt < now) pendingOtps.delete(ref);
  pendingOtps.set(String(referenceNo), { uid, phone, expiresAt: now + OTP_TTL_MS });
}

/** AppsPro unsubscribe succeeded only on S1000 or an UNREGISTERED status (per the AppsPro docs). */
function unsubscribeConfirmed(result) {
  if (!result || typeof result !== 'object') return false;
  const code = result.status_code || result.statusCode;
  const status = result.raw?.subscriptionStatus || result.subscription_status || result.status;
  return code === 'S1000' || String(status || '').toUpperCase() === 'UNREGISTERED' ||
    result.status === 'unsubscribed'; // local sandbox simulation
}

class SubscriptionController {
  /**
   * GET /subscription/status and GET /appspro/subscription
   */
  static async getStatus(req, res) {
    try {
      const uid = req.user.uid;
      let sub = await SubscriptionService.getSubscription(uid);

      // If no active subscription for UID, check if user's phone has an active subscription (e.g., from website subscription portal)
      // Only the phone number Firebase verified at sign-in counts here, never one passed in
      // the request: otherwise anyone could attach (and then cancel) someone else's plan.
      if (!sub || !sub.entitlementActive) {
        const normalizedPhone = verifiedPhone(req);
        if (normalizedPhone) {
          const phoneSub = await SubscriptionService.findSubscriptionByPhone(normalizedPhone);
          if (phoneSub && phoneSub.entitlementActive) {
            console.log(`[SubscriptionController] Linked active website subscription for ${normalizedPhone} to UID ${uid}`);
            sub = await SubscriptionService.saveSubscription(uid, {
              ...phoneSub,
              phone: normalizedPhone,
            });
          }
        }
      }

      if (!sub) {
        return res.status(200).json({
          success: true,
          valid: false,
          status: 'not_subscribed',
          subscription: {
            status: 'not_subscribed',
            entitlementActive: false,
            frequency: null,
            phoneMasked: null,
            subscribedAt: null,
            cancelledAt: null,
          }
        });
      }

      return res.status(200).json({
        success: true,
        valid: sub.entitlementActive,
        status: sub.status,
        subscription: {
          status: sub.status,
          entitlementActive: sub.entitlementActive,
          frequency: sub.frequency,
          phoneMasked: sub.phoneMasked,
          subscribedAt: sub.subscribedAt,
          cancelledAt: sub.cancelledAt,
          lastVerifiedAt: sub.lastVerifiedAt,
        }
      });
    } catch (err) {
      console.error('[SubscriptionController] getStatus error:', err.message);
      return res.status(500).json({
        success: false,
        error: 'SUBSCRIPTION_FETCH_FAILED',
        message: 'Could not retrieve subscription status.',
      });
    }
  }

  /**
   * GET /subscription/app-info and GET /appspro/app-info
   */
  static async getAppInfo(req, res) {
    try {
      const appInfo = await AppsProService.getAppInfo();
      return res.status(200).json(appInfo);
    } catch (err) {
      console.error('[SubscriptionController] getAppInfo error:', err.message);
      return res.status(500).json({
        success: false,
        error: 'APP_INFO_FAILED',
        message: 'Could not retrieve application metadata.',
      });
    }
  }

  /**
   * POST /subscription/otp/request and POST /appspro/otp/request
   */
  static async requestOtp(req, res) {
    try {
      const uid = req.user.uid;
      const { phone } = req.body;

      if (!phone) {
        return res.status(400).json({
          success: false,
          error: 'PHONE_REQUIRED',
          message: 'Phone number is required.',
        });
      }

      const normalizedPhone = normalizeBangladeshPhone(phone);
      if (!normalizedPhone) {
        return res.status(400).json({
          success: false,
          error: 'INVALID_PHONE',
          message: 'Invalid Bangladesh mobile number. Please use a valid 11-digit mobile number.',
        });
      }

      // Check carrier support: BDApps carrier billing specifically works on Robi and Airtel
      const operatorPrefix = normalizedPhone.substring(0, 3);
      const isRobiOrAirtel = operatorPrefix === '018' || operatorPrefix === '016';
      if (!isRobiOrAirtel && process.env.APPSPRO_ENV !== 'sandbox') {
        return res.status(400).json({
          success: false,
          error: 'UNSUPPORTED_OPERATOR',
          message: 'Carrier billing is currently supported for Robi and Airtel numbers. (Supported prefixes: 018, 016).',
        });
      }

      // Call AppsPro OTP request with external_user_id = uid
      const result = await AppsProService.requestOtp(normalizedPhone, uid);

      // Handle user already registered (e.g. BDApps returns statusCode E1351 / "user already registered")
      const isAlreadyRegistered = result.status_code === 'E1351' || 
        result.statusCode === 'E1351' ||
        (result.status_detail || '').toLowerCase().includes('already registered') ||
        (result.statusDetail || '').toLowerCase().includes('already registered') ||
        (result.message || '').toLowerCase().includes('already registered');

      if (isAlreadyRegistered) {
        // No OTP is sent for a number that is already subscribed, so nothing proves this user
        // owns it. Grant it only if Firebase verified this number at sign-in, or it is already
        // this user's own subscription. Otherwise anyone could type a subscribed number, get
        // premium for free, and then cancel the real owner's plan with "Unsubscribe".
        const own = await SubscriptionService.getSubscription(uid);
        const ownsNumber = verifiedPhone(req) === normalizedPhone || Boolean(own && own.phone === normalizedPhone);
        if (!ownsNumber) {
          console.warn(`[SubscriptionController] ${maskPhone(normalizedPhone)} is already subscribed but not proven to belong to ${uid}.`);
          return res.status(409).json({
            success: false,
            error: 'ALREADY_SUBSCRIBED_ELSEWHERE',
            message: 'এই নম্বরে আগে থেকেই সাবস্ক্রিপশন চালু আছে। এই নম্বর দিয়ে (ফোন নম্বরে) লগইন করলে প্রিমিয়াম পাবেন।',
            messageEn: 'This number already has a subscription. Sign in with this phone number to use it.',
          });
        }
        console.log(`[SubscriptionController] Phone ${maskPhone(normalizedPhone)} is already registered to ${uid}. Granting entitlement.`);
        const savedRecord = await SubscriptionService.saveSubscription(uid, {
          status: 'active',
          phone: normalizedPhone,
        });

        return res.status(200).json({
          success: true,
          alreadyRegistered: true,
          valid: true,
          entitlementActive: true,
          status: 'active',
          subscription: {
            status: 'active',
            entitlementActive: true,
            phoneMasked: savedRecord.phoneMasked,
            subscribedAt: savedRecord.subscribedAt,
          },
          message: 'Your phone number is already registered and active!',
        });
      }

      const refNo = result.reference_no || result.referenceNo || result.ref_id || result.data?.reference_no;
      const code = result.status_code || result.statusCode;
      // AppsPro can answer HTTP 200 with an error code (e.g. E13xx) and no reference: no OTP
      // was sent, so do not tell the user to wait for one.
      if (!refNo || (code && String(code).startsWith('E'))) {
        console.warn(`[SubscriptionController] OTP not sent for ${maskPhone(normalizedPhone)}: ${code} ${result.status_detail || ''}`);
        return res.status(502).json({
          success: false,
          error: 'OTP_NOT_SENT',
          status_code: code || null,
          message: 'ওটিপি পাঠানো যায়নি। কিছুক্ষণ পরে আবার চেষ্টা করুন।',
          messageEn: `Could not send the OTP${result.status_detail ? ` (${result.status_detail})` : ''}. Please try again later.`,
        });
      }
      rememberOtp(refNo, uid, normalizedPhone);

      return res.status(200).json({
        success: true,
        reference_no: refNo,
        referenceNo: refNo,
        status_code: result.status_code || result.statusCode || '200',
        message: 'OTP has been sent to your mobile phone.',
      });
    } catch (err) {
      console.error('[SubscriptionController] requestOtp error:', err.message);
      const statusCode = err.status || 500;
      return res.status(statusCode).json({
        success: false,
        error: err.data?.error || 'OTP_REQUEST_FAILED',
        message: err.message || 'Failed to request OTP. Please try again later.',
      });
    }
  }

  /**
   * POST /subscription/otp/verify and POST /appspro/otp/verify
   */
  static async verifyOtp(req, res) {
    try {
      const uid = req.user.uid;
      const referenceNo = req.body.referenceNo || req.body.reference_no;
      const otp = req.body.otp;

      if (!referenceNo || !otp) {
        return res.status(400).json({
          success: false,
          error: 'PARAMS_MISSING',
          message: 'Reference number and OTP code are required.',
        });
      }

      const pending = pendingOtps.get(String(referenceNo));
      if (pending && pending.uid !== uid) {
        return res.status(403).json({
          success: false,
          error: 'OTP_REFERENCE_NOT_YOURS',
          message: 'This OTP was requested from another account. Please request a new OTP.',
        });
      }

      // Call AppsPro OTP verification
      const result = await AppsProService.verifyOtp(referenceNo, String(otp).trim(), uid);

      // Inspect subscription status from AppsPro
      // In AppsPro: status may be 'REGISTERED', 'ACTIVE', 'PENDING', 'INITIAL CHARGING PENDING'
      const rawStatus = result.subscription_status || result.status || 'unknown';
      const subscriberId = result.subscriber_id || result.subscriberId || result.data?.subscriber_id || null;
      const localSubscriberId = result.local_subscriber_id || result.id || null;
      const frequency = result.frequency || result.plan?.frequency || 'daily';
      // The number the OTP went to (remembered at request time), else the one inside the
      // BDApps subscriber id. Never a number sent by the app.
      const subscriberPhone = (pending && pending.phone) || phoneFromSubscriberId(subscriberId) ||
        normalizeBangladeshPhone(result.phone || '');
      if (pending) pendingOtps.delete(String(referenceNo));

      const { status: normalizedStatus, entitlementActive } = SubscriptionService.normalizeStatus(rawStatus);

      // Save subscription record with authoritative status
      const savedRecord = await SubscriptionService.saveSubscription(uid, {
        status: rawStatus,
        appsproSubscriberId: subscriberId,
        appsproLocalSubscriberId: localSubscriberId,
        phone: subscriberPhone,
        frequency: frequency,
        isSandbox: process.env.APPSPRO_ENV === 'sandbox',
      });

      if (entitlementActive) {
        console.log(`[SubscriptionController] OTP verified and subscription ACTIVE for ${uid}. Entitlement GRANTED.`);

        return res.status(200).json({
          success: true,
          valid: true,
          isSubscribed: true,
          subscriber_id: subscriberId,
          subscription_status: 'active',
          status: 'active',
          entitlementActive: true,
          subscription: {
            status: 'active',
            entitlementActive: true,
            frequency: savedRecord.frequency,
            phoneMasked: savedRecord.phoneMasked,
            subscribedAt: savedRecord.subscribedAt,
          },
          message: 'Subscription confirmed successfully.',
        });
      } else if (normalizedStatus === 'pending') {
        console.warn(`[SubscriptionController] OTP verified for ${uid} but charging is PENDING (insufficient balance). Entitlement LOCKED.`);

        return res.status(200).json({
          success: true,
          valid: true,
          isSubscribed: false,
          subscriber_id: subscriberId,
          subscription_status: 'pending',
          status: 'pending',
          entitlementActive: false,
          subscription: {
            status: 'pending',
            entitlementActive: false,
            frequency: savedRecord.frequency,
            phoneMasked: savedRecord.phoneMasked,
            subscribedAt: null,
          },
          message: 'আপনার ওটিপি যাচাই সফল হয়েছে, তবে সিমে পর্যাপ্ত ব্যালেন্স না থাকায় সাবস্ক্রিপশন সক্রিয় করা সম্ভব হয়নি। অনুগ্রহ করে পর্যাপ্ত ব্যালেন্স রিচার্জ করে পুনরায় চেষ্টা করুন।',
          messageEn: 'OTP verified successfully, but subscription could not be activated due to insufficient balance. Please recharge and try again.',
        });
      } else {
        console.warn(`[SubscriptionController] OTP verified but subscription status not active: ${rawStatus}`);
        return res.status(400).json({
          success: false,
          valid: false,
          isSubscribed: false,
          status: normalizedStatus,
          entitlementActive: false,
          error: 'SUBSCRIPTION_NOT_ACTIVE',
          message: `Subscription returned status: ${rawStatus}`,
        });
      }
    } catch (err) {
      console.error('[SubscriptionController] verifyOtp error:', err.message);
      const statusCode = err.status || 400;
      return res.status(statusCode).json({
        success: false,
        error: err.data?.error || 'OTP_VERIFICATION_FAILED',
        message: err.message || 'OTP verification failed. Please check the code and try again.',
      });
    }
  }

  /**
   * POST /subscription/unsubscribe and POST /appspro/unsubscribe
   */
  static async unsubscribe(req, res) {
    try {
      const uid = req.user.uid;
      const sub = await SubscriptionService.getSubscription(uid);

      if (!sub || !sub.phone) {
        return res.status(400).json({
          success: false,
          error: 'NO_ACTIVE_SUBSCRIPTION',
          message: 'No active subscription record found to cancel.',
        });
      }

      // Security: Only unsubscribe the phone linked to the authenticated user
      console.log(`[SubscriptionController] Processing unsubscribe for user ${uid}, phone: ${maskPhone(sub.phone)}`);
      
      try {
        const result = await AppsProService.unsubscribe(sub.phone, uid);
        // HTTP 200 alone is not a cancellation: AppsPro reports the operator's answer in
        // status_code. Unless it is confirmed, the user must not be told billing stopped.
        if (!unsubscribeConfirmed(result)) {
          console.error('[SubscriptionController] Unsubscribe not confirmed:', result && result.status_code, result && result.status_detail);
          return res.status(502).json({
            success: false,
            error: 'UNSUBSCRIBE_NOT_CONFIRMED',
            message: 'We could not confirm the cancellation with your mobile operator. You have NOT been unsubscribed yet. Please try again in a few minutes.',
          });
        }
      } catch (upstreamErr) {
        // Do NOT mark the subscription cancelled if the operator did not confirm it: the user
        // would believe billing stopped while the carrier keeps charging them daily.
        // Only explicit "already unsubscribed / not registered" answers are treated as success.
        const msg = String(upstreamErr.message || '').toLowerCase();
        const alreadyGone = upstreamErr.status === 404 ||
          msg.includes('not registered') || msg.includes('already unsubscribed') ||
          msg.includes('not subscribed') || msg.includes('unregistered');
        if (!alreadyGone) {
          console.error('[SubscriptionController] Upstream unsubscribe failed:', upstreamErr.message);
          return res.status(502).json({
            success: false,
            error: 'UNSUBSCRIBE_UPSTREAM_FAILED',
            message: 'We could not confirm the cancellation with your mobile operator. You have NOT been unsubscribed yet. Please try again in a few minutes.',
          });
        }
        console.warn('[SubscriptionController] Upstream reports subscriber already inactive:', upstreamErr.message);
      }

      const updatedRecord = await SubscriptionService.saveSubscription(uid, {
        status: 'cancelled',
        cancelledAt: new Date().toISOString(),
      });

      return res.status(200).json({
        success: true,
        valid: false,
        status: 'cancelled',
        message: 'Subscription has been cancelled successfully.',
        subscription: {
          status: updatedRecord.status,
          entitlementActive: false,
          cancelledAt: updatedRecord.cancelledAt,
        }
      });
    } catch (err) {
      console.error('[SubscriptionController] unsubscribe error:', err.message);
      return res.status(500).json({
        success: false,
        error: 'UNSUBSCRIBE_FAILED',
        message: 'Failed to cancel subscription. Please try again.',
      });
    }
  }

  /**
   * DELETE /subscription/account
   * Deletes the server-side data for the signed-in user (in-app account deletion).
   * Refuses while carrier billing is still running: deleting the record would hide a
   * subscription the operator keeps charging for. The app cancels it first, then retries.
   */
  static async deleteAccountData(req, res) {
    try {
      const uid = req.user.uid;
      const sub = await SubscriptionService.getSubscription(uid);

      if (sub && (sub.entitlementActive || sub.status === 'active' || sub.status === 'pending')) {
        return res.status(409).json({
          success: false,
          error: 'SUBSCRIPTION_STILL_ACTIVE',
          message: 'Cancel the subscription before deleting the account, so your operator stops charging you.',
        });
      }

      await SubscriptionService.deleteSubscription(uid);
      await SubscriptionService.deleteUserBackup(uid);
      return res.status(200).json({ success: true, deleted: Boolean(sub) });
    } catch (err) {
      console.error('[SubscriptionController] deleteAccountData error:', err.message);
      return res.status(500).json({
        success: false,
        error: 'ACCOUNT_DELETE_FAILED',
        message: 'Could not delete your account data. Please try again.',
      });
    }
  }
}

module.exports = {
  SubscriptionController,
  normalizeBangladeshPhone,
  phoneFromSubscriberId,
  unsubscribeConfirmed,
  _pendingOtps: pendingOtps, // tests only
};
