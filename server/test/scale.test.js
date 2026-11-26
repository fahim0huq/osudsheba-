/**
 * Checks for running with many users:
 *  - website rate limits count per phone number, not per IP (all website visitors reach the
 *    server from the website's own servers, so per-IP would be one limit shared by everyone);
 *  - the live server (Render / NODE_ENV=production) refuses to start with the throw-away JSON
 *    subscription store or with the built-in download-token key.
 */
const http = require('http');
const path = require('path');
const { spawnSync } = require('child_process');
const express = require('express');
const { isLiveServer, assertLiveConfig } = require('../services/production_guard');

let passed = 0;
let failed = 0;
function check(condition, message) {
  if (condition) {
    console.log(`[PASS] ${message}`);
    passed++;
  } else {
    console.error(`[FAIL] ${message}`);
    failed++;
  }
}

function post(port, urlPath, body) {
  return new Promise((resolve, reject) => {
    const req = http.request(
      { hostname: '127.0.0.1', port, path: urlPath, method: 'POST', headers: { 'Content-Type': 'application/json' } },
      (res) => {
        res.resume();
        res.on('end', () => resolve(res.statusCode));
      },
    );
    req.on('error', reject);
    req.end(JSON.stringify(body));
  });
}

/** Loads a server module in a fresh Node process with extra environment; true if it loaded. */
function loads(modulePath, extraEnv) {
  const result = spawnSync(process.execPath, ['-e', `require(${JSON.stringify(modulePath)})`], {
    env: { ...process.env, ...extraEnv },
    encoding: 'utf8',
  });
  return result.status === 0;
}

async function run() {
  console.log('\n=== SCALE / LIVE-SERVER CHECKS ===\n');

  // Live-server detection and the guard itself.
  check(isLiveServer({ RENDER: 'true' }) === true, 'Render counts as the live server');
  check(isLiveServer({ NODE_ENV: 'production' }) === true, 'NODE_ENV=production counts as the live server');
  check(isLiveServer({ NODE_ENV: 'test' }) === false, 'tests are not the live server');
  let threw = false;
  try { assertLiveConfig('x', 'y', { RENDER: 'true' }); } catch { threw = true; }
  check(threw, 'guard refuses on the live server');
  threw = false;
  try { assertLiveConfig('x', 'y', { NODE_ENV: 'development' }); } catch { threw = true; }
  check(!threw, 'guard allows local development');

  // Without Firestore credentials: fine locally, refused on Render.
  const service = path.join(__dirname, '..', 'services', 'subscription.service.js');
  check(loads(service, {}), 'subscription store loads locally without Firestore');
  check(!loads(service, { RENDER: 'true' }), 'subscription store refuses to start on Render without Firestore');

  // Without a token-signing secret: fine locally, refused in production.
  const webRoutes = path.join(__dirname, '..', 'routes', 'web-subscription.routes.js');
  check(loads(webRoutes, { APPSPRO_SECRET_KEY: '', DOWNLOAD_TOKEN_SECRET: '' }), 'website routes load locally without a secret');
  check(
    !loads(webRoutes, { NODE_ENV: 'production', APPSPRO_SECRET_KEY: '', DOWNLOAD_TOKEN_SECRET: '', GOOGLE_APPLICATION_CREDENTIALS: '/nonexistent.json' }),
    'website routes refuse production without a token secret',
  );

  // Website OTP limit: per phone number, so one busy number does not block everyone else.
  const { webSubscriptionRouter } = require('../routes/web-subscription.routes');
  const app = express();
  app.use(express.json());
  app.use('/web-subscription', webSubscriptionRouter);
  const server = await new Promise((resolve) => {
    const s = app.listen(0, '127.0.0.1', () => resolve(s));
  });
  const port = server.address().port;
  try {
    // 017 numbers are rejected (unsupported operator) without calling AppsPro, but each
    // request still counts towards the limit, which is all this needs.
    const busy = '01711111111';
    for (let i = 0; i < 5; i++) await post(port, '/web-subscription/otp/request', { phone: busy });
    check((await post(port, '/web-subscription/otp/request', { phone: busy })) === 429, '6th OTP request for the same number is limited');
    check((await post(port, '/web-subscription/otp/request', { phone: '01722222222' })) !== 429, 'another number from the same address is not limited');
    check((await post(port, '/web-subscription/otp/request', { phone: '+8801711111111' })) === 429, 'the same number written differently shares its limit');
  } finally {
    server.close();
  }

  console.log(`\nScale checks: ${passed} passed, ${failed} failed`);
  process.exit(failed ? 1 : 0);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
