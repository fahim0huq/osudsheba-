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

class SubscriptionController {
  /**
   * GET /subscription/status and GET /appspro/subscription
   */
  static async getStatus(req, res) {
    try {
      const uid = req.user.uid;
      let sub = await SubscriptionService.getSubscription(uid);

      // If no active subscription for UID, check if user's phone has an active subscription (e.g., from website subscription portal)
      if ((!sub || !sub.entitlementActive) && (req.user.phone_number || req.user.phoneNumber || req.query.phone)) {
        const userPhone = req.user.phone_number || req.user.phoneNumber || req.query.phone;
        const normalizedPhone = normalizeBangladeshPhone(userPhone);
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
        console.log(`[SubscriptionController] Phone ${maskPhone(normalizedPhone)} is already registered. Granting entitlement to user ${uid}`);
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
      const phone = req.body.phone;

      if (!referenceNo || !otp) {
        return res.status(400).json({
          success: false,
          error: 'PARAMS_MISSING',
          message: 'Reference number and OTP code are required.',
        });
      }

      // Call AppsPro OTP verification
      const result = await AppsProService.verifyOtp(referenceNo, otp.trim(), uid);

      // Inspect subscription status from AppsPro
      // In AppsPro: status may be 'REGISTERED', 'ACTIVE', 'PENDING', 'INITIAL CHARGING PENDING'
      const rawStatus = result.subscription_status || result.status || 'unknown';
      const subscriberId = result.subscriber_id || result.subscriberId || result.data?.subscriber_id || null;
      const localSubscriberId = result.local_subscriber_id || result.id || null;
      const frequency = result.frequency || result.plan?.frequency || 'daily';
      const subscriberPhone = result.phone || (phone ? normalizeBangladeshPhone(phone) : null);

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
        await AppsProService.unsubscribe(sub.phone, uid);
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

  /**
   * POST /subscription/subscribe
   * Direct server-side subscribe (alternative flow)
   */
  static async directSubscribe(req, res) {
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
          message: 'Invalid Bangladesh mobile number format.',
        });
      }

      const result = await AppsProService.subscribe(normalizedPhone, uid);
      const statusStr = result.subscription_status || result.status || (result.valid ? 'active' : 'unknown');
      const { entitlementActive } = SubscriptionService.normalizeStatus(statusStr);

      const savedRecord = await SubscriptionService.saveSubscription(uid, {
        status: statusStr,
        phone: normalizedPhone,
        appsproSubscriberId: result.subscriber_id || null,
        frequency: result.frequency || 'daily',
      });

      return res.status(200).json({
        success: true,
        entitlementActive,
        subscription: savedRecord,
      });
    } catch (err) {
      console.error('[SubscriptionController] directSubscribe error:', err.message);
      return res.status(err.status || 500).json({
        success: false,
        error: 'DIRECT_SUBSCRIBE_FAILED',
        message: err.message,
      });
    }
  }
}

module.exports = {
  SubscriptionController,
  normalizeBangladeshPhone,
};
