/**
 * Comprehensive Automated Test Suite for AppsPro Subscription Integration
 * Tests HMAC-SHA256 signature verification, idempotency, lifecycle states,
 * entitlement queries, and premium endpoint protection.
 */

const crypto = require('crypto');
const http = require('http');
const dotenv = require('dotenv');

dotenv.config();

const SECRET_KEY = process.env.APPSPRO_WEBHOOK_SECRET || process.env.APPSPRO_SECRET_KEY || 'sk_sandbox_osudsheba_test';
const PORT = 3001; // test server port
process.env.PORT = String(PORT);
process.env.ALLOW_MOCK_AUTH = 'true';
process.env.APPSPRO_ENV = 'sandbox';

// Import services and index
const { SubscriptionService } = require('../services/subscription.service');
const { timingSafeCompare } = require('../webhooks/appspro.webhook');

let server;

function createSignedWebhookRequest(payload, options = {}) {
  const rawBody = Buffer.from(JSON.stringify(payload), 'utf8');
  const timestamp = options.timestamp !== undefined ? options.timestamp : Math.floor(Date.now() / 1000);
  const secret = options.secret !== undefined ? options.secret : SECRET_KEY;

  const bodySha256 = options.bodySha256 !== undefined 
    ? options.bodySha256 
    : crypto.createHash('sha256').update(rawBody).digest('hex');

  const payloadToSign = `${timestamp}.${rawBody.toString('utf8')}`;
  const signature = options.signature !== undefined
    ? options.signature
    : crypto.createHmac('sha256', secret).update(payloadToSign).digest('hex');

  return {
    rawBody,
    headers: {
      'Content-Type': 'application/json',
      'X-Timestamp': String(timestamp),
      'X-Body-Sha256': bodySha256,
      'X-Signature': signature,
      'X-Event-Type': options.eventType || payload.event_type || 'subscriber.created',
      'X-Event-Id': options.eventId || payload.event_id || `evt_test_${Date.now()}`,
    }
  };
}

function sendHttpRequest(path, method, headers, body) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: 'localhost',
      port: PORT,
      path,
      method,
      headers,
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
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
    if (body) req.write(body);
    req.end();
  });
}

async function runTests() {
  console.log('\n======================================================');
  console.log('   STARTING APPSPRO SUBSCRIPTION INTEGRATION TESTS    ');
  console.log('======================================================\n');

  let passed = 0;
  let failed = 0;

  function assert(condition, testName) {
    if (condition) {
      console.log(`[PASS] ${testName}`);
      passed++;
    } else {
      console.error(`[FAIL] ${testName}`);
      failed++;
    }
  }

  // Start test server
  const express = require('express');
  const cors = require('cors');
  const { authenticateFirebaseToken } = require('../middleware/auth.middleware');
  const { requireSubscription } = require('../middleware/requireSubscription');
  const { handleAppsProWebhook } = require('../webhooks/appspro.webhook');
  const subscriptionRoutes = require('../routes/subscription.routes');

  const app = express();
  app.post('/webhooks/appspro', express.raw({ type: 'application/json' }), handleAppsProWebhook);
  app.use(express.json());
  app.use('/subscription', subscriptionRoutes);
  app.use('/appspro', subscriptionRoutes);

  // Mock protected premium endpoint
  app.post('/test-premium-endpoint', authenticateFirebaseToken, requireSubscription, (req, res) => {
    res.json({ success: true, message: 'Premium access granted!' });
  });

  await new Promise((resolve) => {
    server = app.listen(PORT, resolve);
  });
  console.log(`Test server started on http://localhost:${PORT}`);

  try {
    // TEST 1: Timing safe compare
    assert(timingSafeCompare('secret123', 'secret123') === true, 'timingSafeCompare matches equal strings');
    assert(timingSafeCompare('secret123', 'wrong456') === false, 'timingSafeCompare rejects different strings');

    // TEST 2: Status normalization
    assert(SubscriptionService.normalizeStatus('active').entitlementActive === true, 'normalizeStatus: active -> true');
    assert(SubscriptionService.normalizeStatus('pending').entitlementActive === true, 'normalizeStatus: pending -> true');
    assert(SubscriptionService.normalizeStatus('cancelled').entitlementActive === false, 'normalizeStatus: cancelled -> false');
    assert(SubscriptionService.normalizeStatus('unknown_status').entitlementActive === false, 'normalizeStatus: unknown -> false (fails closed)');

    // TEST 3: Webhook with Valid Signature -> 200
    const validEventId = `evt_valid_${Date.now()}`;
    const validPayload = {
      event_id: validEventId,
      event_type: 'subscriber.created',
      external_user_id: 'test_user_sub_1',
      subscriber_id: 'sub_test_123',
      phone: '01812345678',
      created_at: new Date().toISOString(),
    };
    const validReq = createSignedWebhookRequest(validPayload, { eventId: validEventId, eventType: 'subscriber.created' });
    const res1 = await sendHttpRequest('/webhooks/appspro', 'POST', validReq.headers, validReq.rawBody);
    assert(res1.status === 200 && res1.body.success === true, 'Webhook valid HMAC-SHA256 signature accepted with 200');

    // Verify database state
    const subRecord1 = await SubscriptionService.getSubscription('test_user_sub_1');
    assert(subRecord1 && subRecord1.entitlementActive === true && subRecord1.status === 'active', 'Subscription created in DB with entitlementActive = true');

    // TEST 4: Duplicate Webhook Event (Idempotency) -> 200 duplicate: true
    const resDuplicate = await sendHttpRequest('/webhooks/appspro', 'POST', validReq.headers, validReq.rawBody);
    assert(resDuplicate.status === 200 && resDuplicate.body.duplicate === true, 'Webhook idempotency prevents duplicate processing');

    // TEST 5: Webhook with Tampered Body / Invalid SHA256 -> 401
    const tamperedReq = createSignedWebhookRequest(validPayload, {
      bodySha256: '0000000000000000000000000000000000000000000000000000000000000000',
    });
    const resTampered = await sendHttpRequest('/webhooks/appspro', 'POST', tamperedReq.headers, tamperedReq.rawBody);
    assert(resTampered.status === 401 && resTampered.body.error === 'BODY_HASH_MISMATCH', 'Webhook rejects body SHA256 mismatch with 401');

    // TEST 6: Webhook with Expired Timestamp (>5 mins) -> 401
    const expiredTs = Math.floor(Date.now() / 1000) - 400; // 6.6 mins ago
    const expiredReq = createSignedWebhookRequest(validPayload, { timestamp: expiredTs });
    const resExpired = await sendHttpRequest('/webhooks/appspro', 'POST', expiredReq.headers, expiredReq.rawBody);
    assert(resExpired.status === 401 && resExpired.body.error === 'TIMESTAMP_OUT_OF_RANGE', 'Webhook rejects expired timestamp with 401');

    // TEST 7: Webhook with Invalid Signature -> 401
    const badSigReq = createSignedWebhookRequest(validPayload, { signature: 'wrong_hmac_signature' });
    const resBadSig = await sendHttpRequest('/webhooks/appspro', 'POST', badSigReq.headers, badSigReq.rawBody);
    assert(resBadSig.status === 401 && resBadSig.body.error === 'INVALID_SIGNATURE', 'Webhook rejects bad HMAC signature with 401');

    // TEST 8: Webhook Cancellation Event -> entitlementActive = false
    const cancelEventId = `evt_cancel_${Date.now()}`;
    const cancelPayload = {
      event_id: cancelEventId,
      event_type: 'subscriber.cancelled',
      external_user_id: 'test_user_sub_1',
      cancelled_at: new Date().toISOString(),
    };
    const cancelReq = createSignedWebhookRequest(cancelPayload, { eventId: cancelEventId, eventType: 'subscriber.cancelled' });
    const resCancel = await sendHttpRequest('/webhooks/appspro', 'POST', cancelReq.headers, cancelReq.rawBody);
    assert(resCancel.status === 200, 'Webhook subscriber.cancelled processed with 200');

    const subRecordAfterCancel = await SubscriptionService.getSubscription('test_user_sub_1');
    assert(subRecordAfterCancel.entitlementActive === false && subRecordAfterCancel.status === 'cancelled', 'User entitlement revoked after subscriber.cancelled');

    // TEST 9: Unauthenticated call to /subscription/status -> 401
    const resUnauth = await sendHttpRequest('/subscription/status', 'GET', {});
    assert(resUnauth.status === 401, 'Unauthenticated /subscription/status rejected with 401');

    // TEST 10: Authenticated call for unsubscribed user -> status: not_subscribed, entitlementActive: false
    const resStatusUnsub = await sendHttpRequest('/subscription/status', 'GET', {
      'Authorization': 'Bearer mock_token_for_user_fresh_new',
    });
    assert(resStatusUnsub.status === 200 && resStatusUnsub.body.subscription.entitlementActive === false, 'Fresh user status reports not_subscribed and entitlementActive: false');

    // TEST 11: Premium Endpoint Protection (/test-premium-endpoint)
    // User without active subscription is rejected with HTTP 403 SUBSCRIPTION_REQUIRED
    const resPremiumBlocked = await sendHttpRequest('/test-premium-endpoint', 'POST', {
      'Authorization': 'Bearer mock_token_for_user_fresh_new',
    });
    assert(resPremiumBlocked.status === 403 && resPremiumBlocked.body.error === 'SUBSCRIPTION_REQUIRED', 'Unsubscribed user blocked from premium endpoint with 403 SUBSCRIPTION_REQUIRED');

    // TEST 12: Subscribed User allowed on Premium Endpoint
    // Give user an active subscription
    await SubscriptionService.saveSubscription('user_premium_vip', {
      status: 'active',
      phone: '01899999999',
    });
    const resPremiumAllowed = await sendHttpRequest('/test-premium-endpoint', 'POST', {
      'Authorization': 'Bearer mock_token_for_user_premium_vip',
    });
    assert(resPremiumAllowed.status === 200 && resPremiumAllowed.body.success === true, 'Subscribed user allowed on premium endpoint with 200');

    // TEST 13: Pending subscription allowed on Premium Endpoint
    await SubscriptionService.saveSubscription('user_pending_test', {
      status: 'pending',
      phone: '01688888888',
    });
    const resPendingAllowed = await sendHttpRequest('/test-premium-endpoint', 'POST', {
      'Authorization': 'Bearer mock_token_for_user_pending_test',
    });
    assert(resPendingAllowed.status === 200 && resPendingAllowed.body.success === true, 'Pending subscription user allowed on premium endpoint with 200');

    // TEST 14: SMS & USSD Webhooks accepted safely
    const smsReq = createSignedWebhookRequest({
      event_id: `evt_sms_${Date.now()}`,
      event_type: 'sms.received',
      source_address: '8801812345678',
      message: 'STOP',
    }, { eventType: 'sms.received' });
    const resSms = await sendHttpRequest('/webhooks/appspro', 'POST', smsReq.headers, smsReq.rawBody);
    assert(resSms.status === 200, 'Inbound sms.received webhook accepted and processed safely');

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

runTests().catch((err) => {
  console.error('Test suite runner failed:', err);
  if (server) server.close();
  process.exit(1);
});
