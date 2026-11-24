/**
 * Integration points taken from the AppsPro docs (https://appspro.dev/docs), offline:
 *  - account deletion calls DELETE /sdk/subscribers/by-external-id/{external_user_id}
 *  - GET /appspro/subscription speaks the proxy contract { valid, status, reason? }
 *  - the app-info fallback has the /sdk/app-info shape (pricing is a list)
 *  - webhook HMAC covers "<X-Timestamp>." + the exact raw bytes
 *  - a webhook whose processing failed is retried, not skipped as a duplicate
 * AppsPro itself is never contacted: a local HTTP server stands in for it.
 */
const http = require('http');
const crypto = require('crypto');
const { SubscriptionService } = require('../services/subscription.service');
const { SubscriptionController } = require('../controllers/subscription.controller');
const { handleAppsProWebhook } = require('../webhooks/appspro.webhook');
const appsproModule = require('../services/appspro.service');
const { AppsProService } = appsproModule;

let passed = 0;
let failed = 0;
async function test(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`[PASS] ${name}`);
  } catch (err) {
    failed++;
    console.log(`[FAIL] ${name}: ${err.message}`);
  }
}
function eq(actual, expected, what) {
  if (actual !== expected) throw new Error(`${what}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

// ---- in-memory store ----
let store = {};
const deleted = [];
SubscriptionService.getSubscription = async (uid) => store[uid] || null;
SubscriptionService.findSubscriptionByPhone = async () => null;
SubscriptionService.saveSubscription = async (uid, data) => {
  const merged = { ...(store[uid] || {}), ...data, uid };
  const { status, entitlementActive } = SubscriptionService.normalizeStatus(merged.status);
  merged.status = status;
  merged.entitlementActive = entitlementActive;
  store[uid] = merged;
  return merged;
};
SubscriptionService.deleteSubscription = async (uid) => { deleted.push(uid); delete store[uid]; };
SubscriptionService.deleteUserBackup = async () => {};
const events = {};
SubscriptionService.hasWebhookEventBeenProcessed = async (id) => events[id]?.processingStatus === 'processed';
SubscriptionService.recordWebhookEvent = async (id, d) => { events[id] = { ...(events[id] || {}), ...d }; };

function respond(resolve) {
  return {
    statusCode: 200,
    status(c) { this.statusCode = c; return this; },
    json(b) { resolve({ status: this.statusCode, body: b }); },
  };
}
function call(handler, { uid = 'u1', body = {} } = {}) {
  return new Promise((resolve) => handler({ user: { uid }, body, query: {} }, respond(resolve)));
}
function hook(req) {
  return new Promise((resolve) => handleAppsProWebhook(req, respond(resolve)));
}
function signedRequest(bodyBuf, eventType, eventId) {
  const ts = String(Math.floor(Date.now() / 1000));
  const sig = crypto.createHmac('sha256', process.env.APPSPRO_WEBHOOK_SECRET)
    .update(Buffer.concat([Buffer.from(`${ts}.`), bodyBuf])).digest('hex');
  return {
    body: bodyBuf,
    headers: {
      'x-timestamp': ts,
      'x-body-sha256': crypto.createHash('sha256').update(bodyBuf).digest('hex'),
      'x-signature': sig,
      'x-event-type': eventType,
      'x-event-id': eventId,
    },
  };
}

/** Loads a fresh copy of appspro.service.js pointed at a local fake AppsPro. */
async function withFakeAppsPro(statusCode, fn) {
  const seen = [];
  const server = http.createServer((req, res) => {
    seen.push(`${req.method} ${req.url}`);
    res.statusCode = statusCode;
    res.end(statusCode === 204 ? '' : JSON.stringify({ detail: 'Subscriber not found' }));
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const savedUrl = process.env.APPSPRO_BASE_URL;
  const savedSim = process.env.APPSPRO_ALLOW_SIMULATION;
  process.env.APPSPRO_BASE_URL = `http://127.0.0.1:${server.address().port}/api/v1`;
  process.env.APPSPRO_ALLOW_SIMULATION = 'false';
  const modPath = require.resolve('../services/appspro.service');
  delete require.cache[modPath];
  try {
    const fresh = require('../services/appspro.service').AppsProService;
    return await fn(fresh, seen);
  } finally {
    delete require.cache[modPath];
    require.cache[modPath] = { id: modPath, filename: modPath, loaded: true, exports: appsproModule };
    process.env.APPSPRO_BASE_URL = savedUrl;
    process.env.APPSPRO_ALLOW_SIMULATION = savedSim;
    server.close();
  }
}

async function run() {
  console.log('\n=== APPSPRO DOCS TESTS ===\n');

  await test('scrub calls DELETE /api/v1/sdk/subscribers/by-external-id/{uid} (204 = done)', async () => {
    await withFakeAppsPro(204, async (svc, seen) => {
      const r = await svc.deleteSubscriberByExternalId('uid with/slash');
      eq(r.scrubbed, true, 'scrubbed');
      eq(seen[0], 'DELETE /api/v1/sdk/subscribers/by-external-id/uid%20with%2Fslash', 'request');
    });
  });

  await test('scrub treats 404 (AppsPro holds nothing) as done', async () => {
    await withFakeAppsPro(404, async (svc) => {
      const r = await svc.deleteSubscriberByExternalId('u404');
      eq(r.notFound, true, 'notFound');
    });
  });

  await test('scrub throws on other upstream errors when simulation is off', async () => {
    await withFakeAppsPro(500, async (svc) => {
      let threw = false;
      try { await svc.deleteSubscriberByExternalId('u500'); } catch { threw = true; }
      eq(threw, true, 'threw');
    });
  });

  await test('account deletion scrubs at AppsPro, then deletes our record', async () => {
    store = { d1: { uid: 'd1', phone: '01812345678', status: 'cancelled' } };
    const scrubbed = [];
    AppsProService.deleteSubscriberByExternalId = async (id) => { scrubbed.push(id); return { scrubbed: true }; };
    const r = await call(SubscriptionController.deleteAccountData, { uid: 'd1' });
    eq(r.status, 200, 'status');
    eq(scrubbed.join(), 'd1', 'scrubbed external_user_id');
    eq(store.d1, undefined, 'record deleted');
  });

  await test('...deletes nothing when the scrub fails, so the user can retry', async () => {
    store = { d2: { uid: 'd2', phone: '01812345678', status: 'cancelled' } };
    deleted.length = 0;
    AppsProService.deleteSubscriberByExternalId = async () => { const e = new Error('upstream'); e.status = 502; throw e; };
    const r = await call(SubscriptionController.deleteAccountData, { uid: 'd2' });
    eq(r.status, 502, 'status');
    eq(r.body.error, 'BILLING_DATA_DELETE_FAILED', 'error');
    eq(deleted.length, 0, 'nothing deleted');
    eq(store.d2.phone, '01812345678', 'record kept');
  });

  await test('...skips the scrub for a user who never subscribed', async () => {
    store = {};
    let calls = 0;
    AppsProService.deleteSubscriberByExternalId = async () => { calls++; return {}; };
    eq((await call(SubscriptionController.deleteAccountData, { uid: 'never' })).status, 200, 'status');
    eq(calls, 0, 'scrub calls');
  });

  await test('...and still refuses while billing runs (the scrub does not stop billing)', async () => {
    store = { d3: { uid: 'd3', phone: '01812345678', status: 'active' } };
    let calls = 0;
    AppsProService.deleteSubscriberByExternalId = async () => { calls++; return {}; };
    eq((await call(SubscriptionController.deleteAccountData, { uid: 'd3' })).status, 409, 'status');
    eq(calls, 0, 'scrub calls');
  });

  await test('status follows the proxy contract { valid, status, reason? }', async () => {
    store = {};
    const none = await call(SubscriptionController.getStatus, { uid: 'nobody' });
    eq(none.body.valid, false, 'valid');
    eq(none.body.reason, 'not_subscribed', 'reason');
    store = { s1: { uid: 's1', status: 'cancelled' } };
    eq((await call(SubscriptionController.getStatus, { uid: 's1' })).body.reason, 'cancelled', 'cancelled reason');
    store = { s2: { uid: 's2', status: 'active', entitlementActive: true, lastVerifiedAt: new Date().toISOString() } };
    const ok = await call(SubscriptionController.getStatus, { uid: 's2' });
    eq(ok.body.valid, true, 'valid');
    eq(ok.body.reason, null, 'no reason');
  });

  await test('app-info fallback has the documented pricing list and is flagged', async () => {
    const info = await AppsProService.getAppInfo(); // AppsPro unreachable in tests
    eq(Array.isArray(info.pricing), true, 'pricing is a list');
    eq(typeof info.pricing[0].price, 'string', 'price');
    eq(info.pricing[0].billing_period, 'daily', 'billing_period');
    eq(info.fallback, true, 'fallback flag');
    eq('disclosure_md' in info, true, 'disclosure_md key');
  });

  await test('webhook HMAC covers the exact raw bytes, even bytes that are not valid UTF-8', async () => {
    // 0xFF is not valid UTF-8: decoding then re-encoding changes it, so a signature computed
    // over a decoded string would not match the bytes AppsPro signed.
    const body = Buffer.concat([
      Buffer.from('{"event_id":"e-raw","event_type":"sms.received","data":{"sourceAddress":"tel:8801812345678","message":"'),
      Buffer.from([0xff]),
      Buffer.from('"}}'),
    ]);
    const r = await hook(signedRequest(body, 'sms.received', 'e-raw'));
    eq(r.status, 200, 'status');
    eq(events['e-raw'].processingStatus, 'processed', 'processed');
  });

  await test('webhook whose processing failed is marked failed and applied on retry', async () => {
    const realSave = SubscriptionService.saveSubscription;
    SubscriptionService.saveSubscription = async () => { throw new Error('store down'); };
    const body = Buffer.from(JSON.stringify({ event_id: 'e-fail', event_type: 'subscriber.cancelled', data: { external_user_id: 'wf' } }));
    const req = signedRequest(body, 'subscriber.cancelled', 'e-fail');
    const first = await hook(req);
    SubscriptionService.saveSubscription = realSave;
    eq(first.status, 500, 'first delivery');
    eq(events['e-fail'].processingStatus, 'failed', 'marked failed');
    store = { wf: { uid: 'wf', status: 'active', entitlementActive: true } };
    const retry = await hook(req);
    eq(retry.status, 200, 'retry status');
    eq(retry.body.duplicate, undefined, 'not skipped as duplicate');
    eq(store.wf.status, 'cancelled', 'retry applied');
  });

  console.log(`\nTEST SUMMARY: ${passed} PASSED, ${failed} FAILED\n`);
  process.exit(failed ? 1 : 0);
}

run();
