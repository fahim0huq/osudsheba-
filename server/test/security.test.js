/**
 * Security regression tests (offline):
 *  - the free "000000" OTP simulation cannot be enabled by accident
 *  - /subscription/diagnostic is not publicly reachable
 */
const assert = require('assert');
const http = require('http');
const express = require('express');

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

function withEnv(vars, fn) {
  const saved = {};
  for (const k of Object.keys(vars)) {
    saved[k] = process.env[k];
    if (vars[k] === undefined) delete process.env[k];
    else process.env[k] = vars[k];
  }
  try {
    return fn();
  } finally {
    for (const k of Object.keys(saved)) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  }
}

function get(port, path, headers = {}) {
  return new Promise((resolve, reject) => {
    http.get({ host: '127.0.0.1', port, path, headers }, (res) => {
      let body = '';
      res.on('data', (c) => (body += c));
      res.on('end', () => resolve({ status: res.statusCode, body }));
    }).on('error', reject);
  });
}

(async () => {
  const { sandboxSimulationAllowed, AppsProService } = require('../services/appspro.service');

  await check('Simulation OFF when APPSPRO_ALLOW_SIMULATION is unset (even in sandbox/dev env)', () => {
    withEnv({ APPSPRO_ALLOW_SIMULATION: undefined, APPSPRO_ENV: 'development', NODE_ENV: undefined }, () => {
      assert.strictEqual(sandboxSimulationAllowed(), false);
    });
  });

  await check('Simulation OFF in production even if flag is true', () => {
    withEnv({ APPSPRO_ALLOW_SIMULATION: 'true', NODE_ENV: 'production' }, () => {
      assert.strictEqual(sandboxSimulationAllowed(), false);
    });
  });

  await check('Simulation ON only with explicit flag outside production', () => {
    withEnv({ APPSPRO_ALLOW_SIMULATION: 'true', NODE_ENV: 'test' }, () => {
      assert.strictEqual(sandboxSimulationAllowed(), true);
    });
  });

  await check('OTP 000000 does NOT grant a subscription when simulation is off', async () => {
    const saved = { a: process.env.APPSPRO_ALLOW_SIMULATION, n: process.env.NODE_ENV };
    process.env.APPSPRO_ALLOW_SIMULATION = 'false';
    process.env.NODE_ENV = 'development';
    let granted = false;
    try {
      const r = await AppsProService.verifyOtp('ref_sandbox_123_abc', '000000', 'attacker');
      granted = Boolean(r && (r.status === 'active' || r.valid === true));
    } catch {
      granted = false;
    } finally {
      process.env.APPSPRO_ALLOW_SIMULATION = saved.a;
      process.env.NODE_ENV = saved.n;
    }
    assert.strictEqual(granted, false);
  });

  // Diagnostic endpoint
  const router = require('../routes/subscription.routes');
  const app = express();
  app.use('/subscription', router);
  const server = app.listen(0);
  const port = server.address().port;

  await check('GET /subscription/diagnostic is 404 when DIAGNOSTICS_TOKEN is not configured', async () => {
    delete process.env.DIAGNOSTICS_TOKEN;
    const r = await get(port, '/subscription/diagnostic');
    assert.strictEqual(r.status, 404);
  });

  await check('GET /subscription/diagnostic is 404 with a wrong token', async () => {
    process.env.DIAGNOSTICS_TOKEN = 'a_long_operator_token_for_tests_123456';
    const r = await get(port, '/subscription/diagnostic', { 'x-diagnostics-token': 'wrong' });
    assert.strictEqual(r.status, 404);
    delete process.env.DIAGNOSTICS_TOKEN;
  });

  server.close();
  console.log(`\nTEST SUMMARY: ${passed} PASSED, ${failed} FAILED`);
  process.exit(failed ? 1 : 0);
})();
