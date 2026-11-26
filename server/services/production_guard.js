/**
 * Start-up safety checks for the live server.
 *
 * "Live" means Render (which sets RENDER=true) or NODE_ENV=production. There the server must
 * not quietly fall back to development shortcuts: a JSON file on Render's disk is wiped on
 * every restart or deploy (paid subscriptions would vanish), and a signing key written in the
 * code lets anyone forge website download tokens. Failing at start-up makes the deploy fail
 * visibly instead.
 */
function isLiveServer(env = process.env) {
  return env.NODE_ENV === 'production' || env.RENDER === 'true';
}

function assertLiveConfig(problem, fix, env = process.env) {
  if (!isLiveServer(env)) return;
  const message = `[Startup] ${problem} Refusing to start on the live server. ${fix}`;
  console.error(message);
  throw new Error(message);
}

module.exports = { isLiveServer, assertLiveConfig };
