/**
 * AppsPro API Service
 * The authoritative server-side module for direct communication with AppsPro / BDApps.
 */

const https = require('https');
const http = require('http');
const dotenv = require('dotenv');
dotenv.config();

const BASE_URL = (process.env.APPSPRO_BASE_URL || 'https://api.appspro.dev/api/v1').replace(/\/$/, '');
const SECRET_KEY = process.env.APPSPRO_SECRET_KEY || '';
const PUBLISHABLE_KEY = process.env.APPSPRO_PUBLISHABLE_KEY || '';
const TIMEOUT_MS = 30000;

/**
 * Mask phone number for secure logging (e.g. 01712***678)
 */
function maskPhone(phone) {
  if (!phone || typeof phone !== 'string') return '***';
  const clean = phone.trim();
  if (clean.length < 7) return '***';
  return `${clean.slice(0, 5)}***${clean.slice(-3)}`;
}

/**
 * Make an HTTP request to the AppsPro API with a resilient 30-second timeout
 */
async function appsproFetch(endpoint, options = {}) {
  const urlStr = `${BASE_URL}${endpoint.startsWith('/') ? endpoint : `/${endpoint}`}`;
  const u = new URL(urlStr);
  const client = u.protocol === 'https:' ? https : http;

  const headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    ...(SECRET_KEY ? { 'Authorization': `Bearer ${SECRET_KEY}` } : {}),
    ...options.headers,
  };

  return new Promise((resolve, reject) => {
    const req = client.request({
      protocol: u.protocol,
      hostname: u.hostname,
      port: u.port || (u.protocol === 'https:' ? 443 : 80),
      path: u.pathname + u.search,
      method: options.method || 'GET',
      headers,
      timeout: TIMEOUT_MS,
    }, (res) => {
      let responseBody = '';
      res.setEncoding('utf8');
      res.on('data', chunk => responseBody += chunk);
      res.on('end', () => {
        let data;
        try {
          data = JSON.parse(responseBody);
        } catch {
          data = { raw: responseBody };
        }

        if (res.statusCode < 200 || res.statusCode >= 300) {
          const errorMsg = data?.message || data?.error || data?.detail || `AppsPro upstream error (HTTP ${res.statusCode})`;
          console.error(`[AppsPro] Request to ${endpoint} failed (${res.statusCode}):`, errorMsg);
          const error = new Error(errorMsg);
          error.status = res.statusCode;
          error.data = data;
          return reject(error);
        }

        resolve(data);
      });
    });

    req.on('timeout', () => {
      req.destroy();
      const err = new Error('AppsPro service timed out. Please try again later.');
      err.status = 504;
      reject(err);
    });

    req.on('error', (err) => {
      const sanitizedMsg = (err.message || 'Network connection failed').replace(SECRET_KEY, '[REDACTED_SECRET]');
      const networkErr = new Error(`Connection to AppsPro failed: ${sanitizedMsg}`);
      networkErr.status = 502;
      reject(networkErr);
    });

    if (options.body) {
      req.write(typeof options.body === 'string' ? options.body : JSON.stringify(options.body));
    }
    req.end();
  });
}

class AppsProService {
  /**
   * Fetch application metadata and current pricing
   */
  static async getAppInfo() {
    try {
      // app-info accepts query param publishable_key or Bearer token
      const query = PUBLISHABLE_KEY ? `?publishable_key=${encodeURIComponent(PUBLISHABLE_KEY)}` : '';
      return await appsproFetch(`/sdk/app-info${query}`, { method: 'GET' });
    } catch (err) {
      console.warn('[AppsPro] getAppInfo failed, returning fallback metadata:', err.message);
      return {
        app_id: process.env.APPSPRO_APP_ID || 'osudsheba',
        name: 'OsudSheba',
        pricing: {
          amount: '2.00',
          currency: 'BDT',
          frequency: 'daily',
          tax_inclusive: false,
          vat_percentage: '15%',
          sd_percentage: '15%',
          sc_percentage: '1%',
        },
        supported_carriers: ['Robi', 'Airtel'],
        carrier_billing_provider: 'BDApps',
      };
    }
  }

  /**
   * Request OTP for subscription
   */
  static async requestOtp(phone, externalUserId) {
    console.log(`[AppsPro] Requesting OTP for phone: ${maskPhone(phone)}, external_user_id: ${externalUserId}`);
    try {
      const res = await appsproFetch('/sdk/otp/request', {
        method: 'POST',
        body: JSON.stringify({
          phone,
          external_user_id: externalUserId,
        }),
      });
      if ((process.env.APPSPRO_ENV === 'sandbox' || process.env.APPSPRO_ENV === 'development' || process.env.NODE_ENV !== 'production') && (!res.reference_no || (res.status_code && res.status_code.startsWith('E')))) {
        console.warn(`[AppsPro Sandbox] Upstream status (${res.status_code}: ${res.status_detail || 'Non-whitelisted'}). Using local Sandbox OTP simulation (use 000000).`);
        return {
          success: true,
          reference_no: `ref_sandbox_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
          status: 'pending',
          phone,
          message: 'OTP sent successfully (Sandbox: use 000000)'
        };
      }
      return res;
    } catch (err) {
      if (process.env.APPSPRO_ENV === 'sandbox' || process.env.APPSPRO_ENV === 'development' || process.env.NODE_ENV !== 'production') {
        console.warn(`[AppsPro Dev/Sandbox] Upstream error (${err.message}). Using local Sandbox OTP simulation (use 000000).`);
        return {
          success: true,
          reference_no: `ref_sandbox_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
          status: 'pending',
          phone,
          message: 'OTP sent successfully (Sandbox: use 000000)'
        };
      }
      throw err;
    }
  }

  /**
   * Verify OTP and subscribe
   */
  static async verifyOtp(referenceNo, otp, externalUserId) {
    console.log(`[AppsPro] Verifying OTP for ref: ${referenceNo}, external_user_id: ${externalUserId}`);

    // Intercept local sandbox simulation references before upstream call
    if ((referenceNo && referenceNo.startsWith('ref_sandbox_')) || (process.env.APPSPRO_ENV !== 'production' && otp === '000000')) {
      if (otp === '000000') {
        console.log(`[AppsPro Sandbox] Verified simulated OTP ${otp} for ref: ${referenceNo}`);
        const subId = `sub_sandbox_${Buffer.from(externalUserId || 'user').toString('hex').slice(0, 12)}`;
        return {
          success: true,
          status: 'active',
          subscription_status: 'active',
          valid: true,
          subscriber_id: subId,
          reference_no: referenceNo,
          message: 'Subscription successful (Sandbox)'
        };
      } else {
        const invalidErr = new Error('Invalid OTP code. For sandbox testing, please enter 000000.');
        invalidErr.status = 400;
        throw invalidErr;
      }
    }

    try {
      const res = await appsproFetch('/sdk/otp/verify', {
        method: 'POST',
        body: JSON.stringify({
          reference_no: referenceNo,
          otp,
          external_user_id: externalUserId,
        }),
      });
      return res;
    } catch (err) {
      if (process.env.APPSPRO_ENV === 'sandbox') {
        if (otp === '000000' || (referenceNo && referenceNo.startsWith('ref_sandbox_') && otp.length === 6)) {
          console.log(`[AppsPro Sandbox] Verified simulated OTP ${otp} for ref: ${referenceNo}`);
          const subId = `sub_sandbox_${Buffer.from(externalUserId || 'user').toString('hex').slice(0, 12)}`;
          return {
            success: true,
            status: 'active',
            subscriber_id: subId,
            reference_no: referenceNo,
            message: 'Subscription successful (Sandbox)'
          };
        }
        const invalidErr = new Error('Invalid OTP code. For sandbox testing, please enter 000000.');
        invalidErr.status = 400;
        throw invalidErr;
      }
      throw err;
    }
  }

  /**
   * Verify subscriber status using AppsPro local mirror by subscriber ID
   * GET /api/v1/sdk/verify/{subscriber_id}
   */
  static async getSubscriberStatus(subscriberId) {
    try {
      return await appsproFetch(`/sdk/verify/${encodeURIComponent(subscriberId)}`, {
        method: 'GET',
      });
    } catch (err) {
      if (process.env.APPSPRO_ENV === 'sandbox' && subscriberId && subscriberId.startsWith('sub_sandbox_')) {
        return {
          success: true,
          subscriber_id: subscriberId,
          status: 'active',
          is_active: true,
        };
      }
      throw err;
    }
  }

  /**
   * Query live BDApps status by phone
   * POST /api/v1/sdk/status
   */
  static async getLiveStatusByPhone(phone) {
    console.log(`[AppsPro] Querying live BDApps status for phone: ${maskPhone(phone)}`);
    return await appsproFetch('/sdk/status', {
      method: 'POST',
      body: JSON.stringify({ phone }),
    });
  }

  /**
   * Direct server-side subscribe
   */
  static async subscribe(phone, externalUserId) {
    console.log(`[AppsPro] Direct subscribe for phone: ${maskPhone(phone)}, external_user_id: ${externalUserId}`);
    return await appsproFetch('/sdk/subscribe', {
      method: 'POST',
      body: JSON.stringify({
        phone,
        external_user_id: externalUserId,
      }),
    });
  }

  /**
   * Direct server-side unsubscribe
   */
  static async unsubscribe(phone, externalUserId) {
    console.log(`[AppsPro] Unsubscribing phone: ${maskPhone(phone)}, external_user_id: ${externalUserId}`);
    try {
      return await appsproFetch('/sdk/unsubscribe', {
        method: 'POST',
        body: JSON.stringify({
          phone,
          external_user_id: externalUserId,
        }),
      });
    } catch (err) {
      if (process.env.APPSPRO_ENV === 'sandbox') {
        console.log(`[AppsPro Sandbox] Unsubscribed simulated subscriber: ${maskPhone(phone)}`);
        return {
          success: true,
          status: 'unsubscribed',
          message: 'Unsubscribed successfully (Sandbox)'
        };
      }
      throw err;
    }
  }

  /**
   * List subscribers (for admin / reconciliation)
   */
  static async listSubscribers(page = 1, limit = 50, status = '') {
    const params = new URLSearchParams({ page: String(page), limit: String(limit) });
    if (status) params.append('status', status);
    return await appsproFetch(`/sdk/subscribers?${params.toString()}`, {
      method: 'GET',
    });
  }

  /**
   * Batch verification for reconciliation
   */
  static async verifySubscriberBatch(subscriberIds = []) {
    return await appsproFetch('/sdk/verify/batch', {
      method: 'POST',
      body: JSON.stringify({ subscriber_ids: subscriberIds }),
    });
  }
}

module.exports = {
  AppsProService,
  maskPhone,
};
