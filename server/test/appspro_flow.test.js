/**
 * Subscription flow against the AppsPro rules (https://appspro.dev/docs), with AppsPro and
 * the store stubbed: nobody gets premium for a number they have not proven, the phone saved
 * is the one the OTP went to, and "cancelled" is only reported when the operator confirmed it.
 */
const { AppsProService } = require('../services/appspro.service');
const { SubscriptionService } = require('../services/subscription.service');
const {
  SubscriptionController,
  phoneFromSubscriberId,
  unsubscribeConfirmed,
  _pendingOtps,
} = require('../controllers/subscription.controller');
const router = require('../routes/subscription.routes');

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

// ---- stubs ----
let store = {};
SubscriptionService.getSubscription = async (uid) => store[uid] || null;
SubscriptionService.findSubscriptionByPhone = async (phone) =>
  Object.values(store).find((r) => r.phone === phone) || null;
SubscriptionService.saveSubscription = async (uid, data) => {
  const merged = { ...(store[uid] || {}), ...data, uid };
  const { status, entitlementActive } = SubscriptionService.normalizeStatus(merged.status);
  merged.status = status; // like the real store
  merged.entitlementActive = entitlementActive;
  store[uid] = merged;
  return merged;
};

function call(handler, { uid = 'u1', phone, body = {}, query = {} } = {}) {
  return new Promise((resolve) => {
    const req = { user: { uid, ...(phone ? { phone_number: phone } : {}) }, body, query };
    const res = {
      statusCode: 200,
      status(c) { this.statusCode = c; return this; },
      json(b) { resolve({ status: this.statusCode, body: b }); },
    };
    handler(req, res);
  });
}

async function run() {
  console.log('\n=== APPSPRO FLOW TESTS ===\n');

  await test('there is no OTP-free /subscribe route', async () => {
    const paths = router.stack.filter((l) => l.route).map((l) => `${Object.keys(l.route.methods)[0]} ${l.route.path}`);
    eq(paths.includes('post /subscribe'), false, '/subscribe exposed');
    eq(paths.includes('post /otp/verify'), true, 'verify route');
  });

  await test('an already-subscribed number is not handed to someone who has not proven it', async () => {
    store = {};
    AppsProService.requestOtp = async () => ({ status_code: 'E1351', status_detail: 'user already registered' });
    const r = await call(SubscriptionController.requestOtp, { uid: 'stranger', body: { phone: '01812345678' } });
    eq(r.status, 409, 'status');
    eq(r.body.error, 'ALREADY_SUBSCRIBED_ELSEWHERE', 'error');
    eq(store.stranger, undefined, 'nothing saved for the stranger');
  });

  await test('...but it is granted when Firebase verified that number at sign-in', async () => {
    store = {};
    const r = await call(SubscriptionController.requestOtp, { uid: 'owner', phone: '+8801812345678', body: { phone: '01812345678' } });
    eq(r.status, 200, 'status');
    eq(r.body.entitlementActive, true, 'entitlement');
  });

  await test('status does not link a subscription from a phone number passed in the URL', async () => {
    store = { web_01812345678: { uid: 'web_01812345678', phone: '01812345678', status: 'active' } };
    const r = await call(SubscriptionController.getStatus, { uid: 'stranger', query: { phone: '01812345678' } });
    eq(r.body.valid, false, 'valid');
    eq(store.stranger, undefined, 'nothing linked');
  });

  await test('an OTP answer with an error code and no reference is reported as not sent', async () => {
    store = {};
    AppsProService.requestOtp = async () => ({ status_code: 'E1312', status_detail: 'Invalid request' });
    const r = await call(SubscriptionController.requestOtp, { body: { phone: '01812345678' } });
    eq(r.status, 502, 'status');
    eq(r.body.error, 'OTP_NOT_SENT', 'error');
  });

  await test('verify saves the number the OTP went to, not one sent by the app', async () => {
    store = {};
    _pendingOtps.clear();
    AppsProService.requestOtp = async () => ({ reference_no: 'ref1', status_code: 'S1000' });
    AppsProService.verifyOtp = async () => ({ subscription_status: 'REGISTERED', subscriber_id: 'tel:AZ1xyz', status_code: 'S1000' });
    await call(SubscriptionController.requestOtp, { body: { phone: '01812345678' } });
    const r = await call(SubscriptionController.verifyOtp, { body: { reference_no: 'ref1', otp: '123456', phone: '01699999999' } });
    eq(r.body.entitlementActive, true, 'entitlement');
    eq(store.u1.phone, '01812345678', 'saved phone');
  });

  await test('another account cannot use my OTP reference', async () => {
    store = {};
    _pendingOtps.clear();
    await call(SubscriptionController.requestOtp, { uid: 'me', body: { phone: '01812345678' } });
    const r = await call(SubscriptionController.verifyOtp, { uid: 'other', body: { reference_no: 'ref1', otp: '123456' } });
    eq(r.status, 403, 'status');
  });

  await test('the phone is read from a tel: subscriber id when the request was not remembered', async () => {
    eq(phoneFromSubscriberId('tel:8801812345678'), '01812345678', 'tel:880');
    eq(phoneFromSubscriberId('tel:AZ110abc'), null, 'masked id');
  });

  await test('unsubscribe is only "cancelled" when the operator confirmed it', async () => {
    eq(unsubscribeConfirmed({ status_code: 'S1000' }), true, 'S1000');
    eq(unsubscribeConfirmed({ status_code: 'E1356', raw: { subscriptionStatus: 'UNREGISTERED' } }), true, 'UNREGISTERED');
    eq(unsubscribeConfirmed({ status_code: 'E1351', status_detail: 'error' }), false, 'error code');
    eq(unsubscribeConfirmed({}), false, 'empty');

    store = { u1: { uid: 'u1', phone: '01812345678', status: 'active' } };
    AppsProService.unsubscribe = async () => ({ status_code: 'E1601', status_detail: 'System error' });
    const r = await call(SubscriptionController.unsubscribe);
    eq(r.status, 502, 'status');
    eq(store.u1.status, 'active', 'still active');

    AppsProService.unsubscribe = async () => ({ status_code: 'S1000' });
    const ok = await call(SubscriptionController.unsubscribe);
    eq(ok.status, 200, 'confirmed status');
    eq(store.u1.status, 'cancelled', 'cancelled');
  });

  await test('status re-checks an old active plan and removes premium when the operator says UNREGISTERED', async () => {
    const old = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    store = { u1: { uid: 'u1', phone: '01812345678', status: 'active', entitlementActive: true, lastVerifiedAt: old } };
    AppsProService.getLiveStatusByPhone = async () => ({ subscription_status: 'UNREGISTERED', status_code: 'S1000' });
    const r = await call(SubscriptionController.getStatus);
    eq(r.body.valid, false, 'valid');
    eq(store.u1.status, 'cancelled', 'saved as cancelled');
  });

  await test('...keeps premium when the operator still says REGISTERED, or when AppsPro is unreachable', async () => {
    const old = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    store = { u1: { uid: 'u1', phone: '01812345678', status: 'active', entitlementActive: true, lastVerifiedAt: old } };
    AppsProService.getLiveStatusByPhone = async () => ({ subscription_status: 'REGISTERED' });
    eq((await call(SubscriptionController.getStatus)).body.valid, true, 'registered');
    store.u1.lastVerifiedAt = old;
    AppsProService.getLiveStatusByPhone = async () => { const e = new Error('timeout'); e.status = 504; throw e; };
    eq((await call(SubscriptionController.getStatus)).body.valid, true, 'outage');
  });

  await test('...and does not call AppsPro again within 15 minutes', async () => {
    store = { u1: { uid: 'u1', phone: '01812345678', status: 'active', entitlementActive: true, lastVerifiedAt: new Date().toISOString() } };
    let calls = 0;
    AppsProService.getLiveStatusByPhone = async () => { calls++; return { subscription_status: 'UNREGISTERED' }; };
    await call(SubscriptionController.getStatus);
    eq(calls, 0, 'calls');
  });

  const { processEvent } = require('../webhooks/appspro.webhook');

  await test('webhook: subscriber.created at OTP request does not grant premium', async () => {
    store = {};
    await processEvent('subscriber.created', { data: { external_user_id: 'w1', subscriber_id: 'tel:8801812345678' } });
    eq(store.w1, undefined, 'no status -> nothing saved');
    await processEvent('subscriber.created', { data: { external_user_id: 'w1', status: 'PENDING' } });
    eq(store.w1.entitlementActive, false, 'pending -> locked');
  });

  await test('webhook: REGISTERED or subscriber.verified grants premium', async () => {
    store = {};
    await processEvent('subscriber.created', { data: { external_user_id: 'w2', status: 'REGISTERED' } });
    eq(store.w2.entitlementActive, true, 'created REGISTERED');
    await processEvent('subscriber.verified', { data: { external_user_id: 'w3' } });
    eq(store.w3.entitlementActive, true, 'verified');
  });

  await test('webhook: a new OTP request does not lock an already active plan', async () => {
    store = { w4: { uid: 'w4', status: 'active', entitlementActive: true } };
    await processEvent('subscriber.created', { data: { external_user_id: 'w4', status: 'PENDING' } });
    eq(store.w4.status, 'active', 'still active');
    await processEvent('subscriber.cancelled', { data: { external_user_id: 'w4' } });
    eq(store.w4.status, 'cancelled', 'cancel works');
  });

  console.log(`\nTEST SUMMARY: ${passed} PASSED, ${failed} FAILED\n`);
  process.exit(failed ? 1 : 0);
}

run();
