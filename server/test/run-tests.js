/**
 * Runs the offline server test suites against an isolated, empty JSON data store in a
 * temp folder, so tests never read stale records from (or write into) server/data.
 * test_live_appspro.js talks to the real AppsPro API and is intentionally not run here.
 */
const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'osudsheba-test-'));

const env = {
  ...process.env,
  NODE_ENV: 'test',
  APPSPRO_ENV: 'sandbox',
  APPSPRO_ALLOW_SIMULATION: 'true',
  ALLOW_MOCK_AUTH: 'true',
  SUBSCRIPTION_DATA_DIR: tmpDir,
  // Force the local JSON store, never a real Firestore project, during tests
  GOOGLE_APPLICATION_CREDENTIALS: '',
  FIREBASE_CONFIG: '',
  APPSPRO_WEBHOOK_SECRET: 'local_test_webhook_secret',
  // Never let tests reach the real AppsPro API with real keys from server/.env (that could
  // send real OTP SMS or create real subscriptions). Empty values win over .env because
  // dotenv does not override variables that are already set.
  APPSPRO_SECRET_KEY: '',
  APPSPRO_PUBLISHABLE_KEY: '',
  APPSPRO_BASE_URL: 'http://127.0.0.1:9',
};

let failed = false;
for (const suite of ['subscription.test.js', 'web_subscription.test.js', 'security.test.js', 'family.test.js']) {
  try {
    execFileSync(process.execPath, [path.join(__dirname, suite)], { stdio: 'inherit', env });
  } catch {
    failed = true;
  }
}
fs.rmSync(tmpDir, { recursive: true, force: true });
process.exit(failed ? 1 : 0);
