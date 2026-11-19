/**
 * POST /family/remind (offline, with a fake Firestore and a fake push sender).
 */
const assert = require('assert');
const http = require('http');
const express = require('express');
const { createFamilyRouter, DEFAULT_MESSAGE } = require('../routes/family.routes');

let passed = 0;
let failed = 0;
async function check(name, fn) {
  try {
    await fn();
    console.log(`[PASS] ${name}`);
    passed++;
  } catch (e) {
    console.log(`[FAIL] ${name}: ${e.message}`);
    failed++;
  }
}

/** Fake Firestore: { 'users/p1/family/c1': {...}, 'users/p1/devices/tok1': {...} } */
function fakeDb(docs) {
  const deleted = [];
  const ref = (path) => ({
    collection: (name) => col(`${path}/${name}`),
    get: async () => ({ exists: path in docs, data: () => docs[path] }),
    delete: async () => { deleted.push(path); delete docs[path]; },
  });
  const col = (path) => ({
    doc: (id) => ref(`${path}/${id}`),
    get: async () => ({
      docs: Object.keys(docs)
        .filter((k) => k.startsWith(`${path}/`) && !k.slice(path.length + 1).includes('/'))
        .map((k) => ({ id: k.slice(path.length + 1), data: () => docs[k] })),
    }),
  });
  return { collection: (name) => col(name), deleted };
}

function request(port, body, token) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request({
      hostname: 'localhost', port, path: '/family/remind', method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    }, (res) => {
      let out = '';
      res.on('data', (c) => (out += c));
      res.on('end', () => resolve({ status: res.statusCode, body: out ? JSON.parse(out) : {} }));
    });
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function withServer(deps, fn) {
  const app = express();
  app.use(express.json());
  app.use('/family', createFamilyRouter(deps));
  const server = await new Promise((r) => { const s = app.listen(0, () => r(s)); });
  try {
    await fn(server.address().port);
  } finally {
    server.close();
  }
}

(async () => {
  console.log('\n=== FAMILY REMINDER TESTS ===\n');
  const pushes = [];
  const sendPush = async (tokens, notification, data) => {
    pushes.push({ tokens, notification, data });
    return {
      successCount: tokens.filter((t) => t !== 'dead').length,
      responses: tokens.map((t) => (t === 'dead'
        ? { success: false, error: { code: 'messaging/registration-token-not-registered' } }
        : { success: true })),
    };
  };
  const db = fakeDb({
    'users/p1/family/c1': { status: 'active', caregiverName: 'Rahim' },
    'users/p1/family/c2': { status: 'pending', caregiverName: 'Karim' },
    'users/p1/devices/tok1': { platform: 'android' },
    'users/p1/devices/dead': { platform: 'android' },
  });

  await withServer({ getDb: () => db, sendPush }, async (port) => {
    await check('rejects a request without sign-in (401)', async () => {
      const r = await request(port, { patientUid: 'p1' });
      assert.strictEqual(r.status, 401);
    });
    await check('rejects a missing or malformed person id (400)', async () => {
      assert.strictEqual((await request(port, {}, 'mock_token_for_c1')).status, 400);
      assert.strictEqual((await request(port, { patientUid: 'p1/devices' }, 'mock_token_for_c1')).status, 400);
    });
    await check('a stranger cannot send reminders (403)', async () => {
      const r = await request(port, { patientUid: 'p1' }, 'mock_token_for_stranger');
      assert.strictEqual(r.status, 403);
      assert.strictEqual(r.body.error, 'NOT_LINKED');
    });
    await check('a caregiver still waiting for approval cannot send reminders (403)', async () => {
      const r = await request(port, { patientUid: 'p1' }, 'mock_token_for_c2');
      assert.strictEqual(r.status, 403);
    });
    await check('an approved caregiver reaches the person\'s phones, titled with their name', async () => {
      pushes.length = 0;
      const r = await request(port, { patientUid: 'p1', message: 'Abba, please take your 8 PM medicine' }, 'mock_token_for_c1');
      assert.strictEqual(r.status, 200);
      assert.strictEqual(r.body.delivered, 1);
      assert.deepStrictEqual(pushes[0].tokens.sort(), ['dead', 'tok1']);
      assert.strictEqual(pushes[0].notification.title, 'Rahim');
      assert.strictEqual(pushes[0].notification.body, 'Abba, please take your 8 PM medicine');
    });
    await check('an empty message gets the default bilingual text', async () => {
      pushes.length = 0;
      await request(port, { patientUid: 'p1', message: '  ' }, 'mock_token_for_c1');
      assert.strictEqual(pushes[0].notification.body, DEFAULT_MESSAGE);
    });
    await check('tokens of uninstalled apps are forgotten', async () => {
      assert.ok(db.deleted.includes('users/p1/devices/dead'));
    });
  });

  await withServer({ getDb: () => null, sendPush }, async (port) => {
    await check('without Firestore configured the server says unavailable (503)', async () => {
      const r = await request(port, { patientUid: 'p1' }, 'mock_token_for_c1');
      assert.strictEqual(r.status, 503);
    });
  });

  console.log(`\nTEST SUMMARY: ${passed} PASSED, ${failed} FAILED\n`);
  process.exit(failed > 0 ? 1 : 0);
})();
