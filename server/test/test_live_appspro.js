/**
 * Test AppsPro Live API Connectivity with current .env configuration.
 * Verifies URL reachability, API key headers, app-info endpoint, and sandbox OTP request.
 * NOTE: Never prints the secret key.
 */

const dotenv = require('dotenv');
dotenv.config();

const BASE_URL = (process.env.APPSPRO_BASE_URL || 'https://api.appspro.dev/api/v1').replace(/\/$/, '');
const PUB_KEY = process.env.APPSPRO_PUBLISHABLE_KEY || '';
const SEC_KEY = process.env.APPSPRO_SECRET_KEY || '';
const APP_ID = process.env.APPSPRO_APP_ID || '';
const ENV = process.env.APPSPRO_ENV || 'sandbox';

function maskKey(key) {
  if (!key) return '(not set)';
  if (key.length <= 8) return '****';
  return `${key.slice(0, 6)}...${key.slice(-4)} (${key.length} chars)`;
}

async function testEnvAndApi() {
  console.log('\n======================================================');
  console.log('       TESTING CURRENT APPSPRO ENVIRONMENT DATA       ');
  console.log('======================================================\n');

  console.log('Environment Configuration Status:');
  console.log(`- APPSPRO_BASE_URL:        ${BASE_URL}`);
  console.log(`- APPSPRO_ENV:             ${ENV}`);
  console.log(`- APPSPRO_APP_ID:          ${APP_ID || '(not set)'}`);
  console.log(`- APPSPRO_PUBLISHABLE_KEY: ${maskKey(PUB_KEY)}`);
  console.log(`- APPSPRO_SECRET_KEY:      ${maskKey(SEC_KEY)}`);
  console.log(`- APPSPRO_WEBHOOK_SECRET:  ${maskKey(process.env.APPSPRO_WEBHOOK_SECRET)}`);
  console.log('');

  // 1. Test Base URL connectivity
  console.log('1. Testing connectivity to AppsPro API Base URL...');
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 8000);
    const res = await fetch(BASE_URL, { signal: controller.signal });
    clearTimeout(timeout);
    console.log(`   [STATUS] Root reached with HTTP ${res.status}`);
  } catch (err) {
    console.log(`   [NOTICE] Root check: ${err.message}`);
  }

  // 2. Test /sdk/app-info
  console.log('\n2. Testing /sdk/app-info with APPSPRO_PUBLISHABLE_KEY...');
  try {
    const query = PUB_KEY ? `?publishable_key=${encodeURIComponent(PUB_KEY)}` : '';
    const url = `${BASE_URL}/sdk/app-info${query}`;
    const res = await fetch(url, {
      headers: {
        'Accept': 'application/json',
        ...(SEC_KEY ? { 'Authorization': `Bearer ${SEC_KEY}` } : {}),
      }
    });

    const bodyText = await res.text();
    let parsed;
    try { parsed = JSON.parse(bodyText); } catch { parsed = bodyText; }

    console.log(`   [STATUS] HTTP ${res.status}`);
    console.log('   [RESPONSE]:', typeof parsed === 'object' ? JSON.stringify(parsed, null, 2) : parsed);
  } catch (err) {
    console.log(`   [ERROR] ${err.message}`);
  }

  // 3. Test Protected endpoint /sdk/subscribers using Secret Key
  console.log('\n3. Testing protected endpoint /sdk/subscribers with APPSPRO_SECRET_KEY...');
  try {
    const res = await fetch(`${BASE_URL}/sdk/subscribers?limit=1`, {
      headers: {
        'Accept': 'application/json',
        'Authorization': `Bearer ${SEC_KEY}`,
      }
    });

    const bodyText = await res.text();
    let parsed;
    try { parsed = JSON.parse(bodyText); } catch { parsed = bodyText; }

    console.log(`   [STATUS] HTTP ${res.status}`);
    console.log('   [RESPONSE]:', typeof parsed === 'object' ? JSON.stringify(parsed, null, 2) : parsed);
  } catch (err) {
    console.log(`   [ERROR] ${err.message}`);
  }

  // 4. Test Sandbox OTP Request (Robi 018 test number)
  console.log('\n4. Testing /sdk/otp/request with test Robi number (01812345678)...');
  try {
    const res = await fetch(`${BASE_URL}/sdk/otp/request`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': `Bearer ${SEC_KEY}`,
      },
      body: JSON.stringify({
        phone: '01812345678',
        external_user_id: 'test_env_eval_user',
      })
    });

    const bodyText = await res.text();
    let parsed;
    try { parsed = JSON.parse(bodyText); } catch { parsed = bodyText; }

    console.log(`   [STATUS] HTTP ${res.status}`);
    console.log('   [RESPONSE]:', typeof parsed === 'object' ? JSON.stringify(parsed, null, 2) : parsed);
  } catch (err) {
    console.log(`   [ERROR] ${err.message}`);
  }

  console.log('\n======================================================');
  console.log('                  TEST RUN COMPLETE                   ');
  console.log('======================================================\n');
}

testEnvAndApi().catch(console.error);
