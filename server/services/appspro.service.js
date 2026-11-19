/**
 * AppsPro API Service
 * The authoritative server-side module for direct communication with AppsPro / BDApps.
 */

const https = require('https');
const http = require('http');
const dotenv = require('dotenv');
dotenv.config();

const BASE_URL = (process.env.APPSPRO_BASE_URL || 'https://api.appspro.dev/api/v1').replace(/\/$/, '');
const SECRET_KEY = (process.env.APPSPRO_SECRET_KEY || '').trim();
const PUBLISHABLE_KEY = (process.env.APPSPRO_PUBLISHABLE_KEY || '').trim();
const TIMEOUT_MS = 30000;

/**
 * Local OTP/subscription simulation (OTP "000000", ref_sandbox_* references) grants a
 * subscription WITHOUT charging anyone. It must therefore be an explicit opt-in that can
 * never be active on a live server by accident:
 *   - APPSPRO_ALLOW_SIMULATION must be exactly "true", AND
 *   - NODE_ENV must not be "production".
 * (Previously any server where APPSPRO_ENV was not literally "production" accepted 000000.)
 */
function sandboxSimulationAllowed() {
  return process.env.APPSPRO_ALLOW_SIMULATION === 'true' && process.env.NODE_ENV !== 'production';
}

/**
 * Get safe fingerprint for publishable key: first 6 + last 4 chars
 */
function getPublishableKeyFingerprint(key = PUBLISHABLE_KEY) {
  if (!key || typeof key !== 'string') return '(not set)';
  const clean = key.trim();
  if (clean.length <= 10) return '****';
  return `${clean.slice(0, 6)}...${clean.slice(-4)}`;
}

/**
 * Get safe fingerprint for secret key: first 4 + last 4 chars
 */
function getSecretKeyFingerprint(key = SECRET_KEY) {
  if (!key || typeof key !== 'string') return '(not set)';
  const clean = key.trim();
  if (clean.length <= 8) return '****';
  return `${clean.slice(0, 4)}...${clean.slice(-4)}`;
}

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
    const maskedKey = getPublishableKeyFingerprint(PUBLISHABLE_KEY);
    const maskedPath = `/sdk/app-info?publishable_key=${maskedKey}`;
    console.log(`[AppsPro Diagnostics] Requesting getAppInfo: ${maskedPath}`);
    try {
      // app-info accepts query param publishable_key or Bearer token
      const query = PUBLISHABLE_KEY ? `?publishable_key=${encodeURIComponent(PUBLISHABLE_KEY)}` : '';
      const data = await appsproFetch(`/sdk/app-info${query}`, { method: 'GET' });
      console.log('[AppsPro Diagnostics] getAppInfo OK (HTTP 200).');
      return data;
    } catch (err) {
      console.error(`[AppsPro Diagnostics] getAppInfo response (HTTP ${err.status || 500}):`, JSON.stringify(err.data || err.message));
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
   * Test protected AppsPro API (/sdk/subscribers) using configured secret key
   * Safely logs HTTP status and response body (NEVER exposes secret key).
   */
  static async testProtectedSubscribers() {
    console.log(`[AppsPro Diagnostics] Testing protected /sdk/subscribers with configured secret key...`);
    try {
      // Only report whether the secret key is accepted. The response body contains subscriber
      // records (phone numbers), so it is never logged or returned.
      await appsproFetch('/sdk/subscribers?limit=1', { method: 'GET' });
      console.log('[AppsPro Diagnostics] /sdk/subscribers reachable with configured secret key (HTTP 200).');
      return { status: 200, ok: true };
    } catch (err) {
      console.error(`[AppsPro Diagnostics] /sdk/subscribers failed (HTTP ${err.status || 500}): ${err.message}`);
      return { status: err.status || 500, ok: false, error: err.message };
    }
  }

  /**
   * Log startup configuration safely without printing full secrets
   */
  static logStartupDiagnostics() {
    console.log('\n======================================================');
    console.log('       APPSPRO RUNTIME CONFIGURATION DIAGNOSTICS      ');
    console.log('======================================================');
    console.log(`- APPSPRO_BASE_URL:               ${BASE_URL}`);
    console.log(`- APPSPRO_ENV:                    ${process.env.APPSPRO_ENV || '(not set)'}`);
    console.log(`- APPSPRO_PUBLISHABLE_KEY exists: ${Boolean(PUBLISHABLE_KEY)}`);
    console.log(`- Publishable Key Fingerprint:    ${getPublishableKeyFingerprint(PUBLISHABLE_KEY)}`);
    console.log(`- Publishable Key Length:         ${PUBLISHABLE_KEY ? PUBLISHABLE_KEY.length : 0}`);
    console.log(`- APPSPRO_SECRET_KEY exists:      ${Boolean(SECRET_KEY)}`);
    console.log(`- Secret Key Fingerprint:         ${getSecretKeyFingerprint(SECRET_KEY)}`);
    console.log(`- Secret Key Length:              ${SECRET_KEY ? SECRET_KEY.length : 0}`);
    console.log('======================================================\n');
  }

  /**
   * Run full non-sensitive diagnostics for safe endpoint inspection
   */
  static async runDiagnostics() {
    let appInfoTest = null;
    try {
      const query = PUBLISHABLE_KEY ? `?publishable_key=${encodeURIComponent(PUBLISHABLE_KEY)}` : '';
      const data = await appsproFetch(`/sdk/app-info${query}`, { method: 'GET' });
      appInfoTest = { status: 200, data };
    } catch (err) {
      appInfoTest = { status: err.status || 500, data: err.data || err.message };
    }

    const subscribersTest = await AppsProService.testProtectedSubscribers();

    return {
      runtime: {
        APPSPRO_BASE_URL: BASE_URL,
        APPSPRO_ENV: process.env.APPSPRO_ENV || '(not set)',
        publishableKey: {
          exists: Boolean(PUBLISHABLE_KEY),
          fingerprint: getPublishableKeyFingerprint(PUBLISHABLE_KEY),
          length: PUBLISHABLE_KEY ? PUBLISHABLE_KEY.length : 0,
        },
        secretKey: {
          exists: Boolean(SECRET_KEY),
          fingerprint: getSecretKeyFingerprint(SECRET_KEY),
          length: SECRET_KEY ? SECRET_KEY.length : 0,
        },
      },
      tests: {
        appInfo: appInfoTest,
        subscribers: subscribersTest,
      },
    };
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
      if (sandboxSimulationAllowed() && (!res.reference_no || (res.status_code && res.status_code.startsWith('E')))) {
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
      if (sandboxSimulationAllowed()) {
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
    if (sandboxSimulationAllowed() && ((referenceNo && referenceNo.startsWith('ref_sandbox_')) || otp === '000000')) {
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
      if (sandboxSimulationAllowed()) {
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
      if (sandboxSimulationAllowed() && subscriberId && subscriberId.startsWith('sub_sandbox_')) {
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
      if (sandboxSimulationAllowed()) {
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
  sandboxSimulationAllowed,
  maskPhone,
  getPublishableKeyFingerprint,
  getSecretKeyFingerprint,
};
