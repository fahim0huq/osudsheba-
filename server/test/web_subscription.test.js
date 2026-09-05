/**
 * OsudSheba Web Subscription Integration Tests
 * Tests unauthenticated website subscription flow, Robi/Airtel carrier validation,
 * AppsPro OTP verification, download token gating, and Flutter mobile sync.
 */

const http = require('http');
const express = require('express');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '..', '.env') });
process.env.APPSPRO_ENV = 'sandbox';
process.env.NODE_ENV = 'test';
process.env.ALLOW_MOCK_AUTH = 'true';

const { webSubscriptionRouter, isSupportedCarrier, verifyDownloadToken } = require('../routes/web-subscription.routes');
const subscriptionRoutes = require('../routes/subscription.routes');
const { SubscriptionService } = require('../services/subscription.service');
const { authenticateFirebaseToken } = require('../middleware/auth.middleware');

const PORT = 3002;
let server;

function sendHttpRequest(path, method = 'GET', headers = {}, body = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: PORT,
      path,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, headers: res.headers, body: parsed });
        } catch {
          resolve({ status: res.statusCode, headers: res.headers, body: data });
        }
      });
    });

    req.on('error', reject);
    if (body) {
      req.write(typeof body === 'string' ? body : JSON.stringify(body));
    }
    req.end();
  });
}

async function runWebTests() {
  console.log('\n======================================================');
  console.log('   STARTING WEBSITE SUBSCRIPTION INTEGRATION TESTS    ');
  console.log('======================================================\n');

  const app = express();
  app.use(express.json());
  app.use('/web-subscription', webSubscriptionRouter);
  app.use('/subscription', subscriptionRoutes);

  await new Promise((resolve) => {
    server = app.listen(PORT, resolve);
  });
  console.log(`Web test server running on http://localhost:${PORT}`);

  let passed = 0;
  let failed = 0;

  function assert(condition, message) {
    if (condition) {
      console.log(`[PASS] ${message}`);
      passed++;
    } else {
      console.error(`[FAIL] ${message}`);
      failed++;
    }
  }

  try {
    // TEST 1: Carrier validation unit check
    assert(isSupportedCarrier('01812345678') === true, 'isSupportedCarrier: Robi (018) is supported');
    assert(isSupportedCarrier('01612345678') === true, 'isSupportedCarrier: Airtel (016) is supported');
    assert(isSupportedCarrier('01712345678') === false, 'isSupportedCarrier: Grameenphone (017) rejected');
    assert(isSupportedCarrier('01912345678') === false, 'isSupportedCarrier: Banglalink (019) rejected');

    // TEST 2: GET /web-subscription/app-info returns 2.00 BDT daily
    const resAppInfo = await sendHttpRequest('/web-subscription/app-info', 'GET');
    assert(resAppInfo.status === 200 && resAppInfo.body.pricing.amount === '2.00', 'GET /app-info returns 2.00 BDT daily pricing');
    assert(resAppInfo.body.supported_carriers.includes('Robi'), 'GET /app-info lists Robi carrier support');

    // TEST 3: POST /web-subscription/otp/request with unsupported carrier (017...) -> 400
    const resUnsupported = await sendHttpRequest('/web-subscription/otp/request', 'POST', {}, { phone: '01712345678' });
    assert(resUnsupported.status === 400 && resUnsupported.body.error === 'UNSUPPORTED_OPERATOR', 'Request OTP with non-Robi/Airtel operator returns 400 UNSUPPORTED_OPERATOR');

    // TEST 4: POST /web-subscription/otp/request with invalid phone format -> 400
    const resInvalidPhone = await sendHttpRequest('/web-subscription/otp/request', 'POST', {}, { phone: '123' });
    assert(resInvalidPhone.status === 400 && resInvalidPhone.body.error === 'INVALID_PHONE_FORMAT', 'Request OTP with invalid phone format returns 400 INVALID_PHONE_FORMAT');

    // TEST 5: POST /web-subscription/otp/request with supported Robi phone (01899112233) -> 200
    const robiPhone = '01899112233';
    const resOtpReq = await sendHttpRequest('/web-subscription/otp/request', 'POST', {}, { phone: robiPhone });
    assert(resOtpReq.status === 200 && resOtpReq.body.success === true, 'Request OTP for Robi number succeeds with 200');
    assert(Boolean(resOtpReq.body.reference_no), 'Request OTP returns reference_no');
    const referenceNo = resOtpReq.body.reference_no;

    // TEST 6: POST /web-subscription/otp/verify with invalid OTP -> 400
    const resBadOtp = await sendHttpRequest('/web-subscription/otp/verify', 'POST', {}, {
      referenceNo,
      otp: '999999',
      phone: robiPhone,
    });
    assert(resBadOtp.status === 400, 'Verify OTP with wrong code rejected with 400');

    // TEST 7: POST /web-subscription/otp/verify with valid sandbox OTP (000000) -> 200 & active
    const resVerify = await sendHttpRequest('/web-subscription/otp/verify', 'POST', {}, {
      referenceNo,
      otp: '000000',
      phone: robiPhone,
    });
    assert(resVerify.status === 200 && resVerify.body.valid === true, 'Verify OTP succeeds with 200 and valid = true');
    assert(Boolean(resVerify.body.downloadToken), 'Verify OTP returns signed downloadToken');
    assert(resVerify.body.status === 'active', 'Verify OTP returns status = active');
    const downloadToken = resVerify.body.downloadToken;

    // TEST 8: Verify download token integrity
    const tokenPayload = verifyDownloadToken(downloadToken);
    assert(tokenPayload && tokenPayload.phone === robiPhone, 'verifyDownloadToken decodes and validates signature for correct phone');

    // TEST 9: GET /web-subscription/download-check without token -> 403
    const resBlockedDownload = await sendHttpRequest('/web-subscription/download-check', 'GET');
    assert(resBlockedDownload.status === 403 && resBlockedDownload.body.error === 'SUBSCRIPTION_REQUIRED', 'Download check without subscription or token blocked with 403');

    // TEST 10: GET /web-subscription/download-check with valid download token -> 200
    const resAllowedDownload = await sendHttpRequest(`/web-subscription/download-check?token=${encodeURIComponent(downloadToken)}`, 'GET');
    assert(resAllowedDownload.status === 200 && resAllowedDownload.body.success === true, 'Download check with valid token succeeds with 200');

    // TEST 11: POST /web-subscription/status returns active entitlement
    const resStatus = await sendHttpRequest('/web-subscription/status', 'POST', {}, { phone: robiPhone });
    assert(resStatus.status === 200 && resStatus.body.valid === true && resStatus.body.status === 'active', 'Status check for subscribed phone returns active entitlement');

    // TEST 12: Repeat OTP request for already subscribed phone -> alreadyRegistered: true
    const resRepeat = await sendHttpRequest('/web-subscription/otp/request', 'POST', {}, { phone: robiPhone });
    assert(resRepeat.status === 200 && resRepeat.body.alreadyRegistered === true, 'Requesting OTP for already subscribed number returns alreadyRegistered: true');

    // TEST 13: Cross-Platform Entitlement Sync (Flutter App Startup Gate)
    // A mobile user signs into Flutter app via Firebase Phone Auth with 01899112233
    // Flutter app calls GET /subscription/status with Firebase Auth header
    const resMobileAppCheck = await sendHttpRequest(`/subscription/status?phone=${robiPhone}`, 'GET', {
      'Authorization': 'Bearer mock_token_for_new_mobile_user_abc',
    });
    assert(resMobileAppCheck.status === 200 && resMobileAppCheck.body.valid === true, 'Mobile app sync automatically links website subscription to Firebase UID and confirms entitlement');

    console.log('\n======================================================');
    console.log(`TEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
    console.log('======================================================\n');
  } finally {
    if (server) {
      server.close();
    }
  }

  if (failed > 0) {
    process.exit(1);
  }
}

runWebTests().catch((err) => {
  console.error('Web test runner error:', err);
  if (server) server.close();
  process.exit(1);
});
