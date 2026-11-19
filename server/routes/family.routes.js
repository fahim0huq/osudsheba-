/**
 * Family routes (docs/FAMILY_SHARING_PLAN.md, Phase 2).
 *
 * POST /family/remind  { patientUid, message }
 *   A caregiver sends a reminder to someone they look after. The server checks that the
 *   caller is an APPROVED caregiver of that person (users/{patientUid}/family/{callerUid}
 *   with status "active"), then sends a push notification to the person's registered
 *   devices (users/{patientUid}/devices/{token}). The app also stores the reminder in
 *   Firestore itself, so it is still shown in the app if the push fails.
 *
 * Dependencies are injectable so tests can run without Firebase.
 */
const express = require('express');
const rateLimit = require('express-rate-limit');
const { authenticateFirebaseToken } = require('../middleware/auth.middleware');

const DEFAULT_MESSAGE = 'ওষুধ খাওয়ার সময় হয়েছে। Time to take your medicine.';
const DEAD_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

function defaultDeps() {
  const configured = Boolean(process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.FIREBASE_CONFIG);
  const app = () => {
    const { getApps, initializeApp } = require('firebase-admin/app');
    return getApps()[0] || initializeApp({ projectId: process.env.FIREBASE_PROJECT_ID || 'osudsheba-7b88a' });
  };
  return {
    getDb: () => {
      if (!configured) return null;
      const { getFirestore } = require('firebase-admin/firestore');
      return getFirestore(app());
    },
    sendPush: (tokens, notification, data) => {
      const { getMessaging } = require('firebase-admin/messaging');
      return getMessaging(app()).sendEachForMulticast({
        tokens,
        notification,
        data,
        android: { priority: 'high', notification: { channelId: 'family_reminders' } },
      });
    },
  };
}

function createFamilyRouter(deps = defaultDeps()) {
  const router = express.Router();

  // A caregiver tapping "Send reminder" repeatedly should not flood the other phone.
  const remindLimiter = rateLimit({
    windowMs: 10 * 60 * 1000,
    max: 10,
    keyGenerator: (req) => (req.user ? req.user.uid : req.ip),
    validate: false,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, error: 'RATE_LIMITED', message: 'Too many reminders. Please wait a few minutes.' },
  });

  router.post('/remind', authenticateFirebaseToken, remindLimiter, async (req, res) => {
    const callerUid = req.user.uid;
    const { patientUid, message } = req.body || {};
    if (typeof patientUid !== 'string' || !patientUid || patientUid.includes('/') || patientUid === callerUid) {
      return res.status(400).json({ success: false, error: 'INVALID_PATIENT' });
    }
    const text = typeof message === 'string' && message.trim() ? message.trim().slice(0, 200) : DEFAULT_MESSAGE;

    let db;
    try {
      db = deps.getDb();
    } catch (err) {
      console.error('[Family] Firestore unavailable:', err.message);
    }
    if (!db) {
      return res.status(503).json({ success: false, error: 'FAMILY_UNAVAILABLE', message: 'Reminders are not available right now.' });
    }

    try {
      const patient = db.collection('users').doc(patientUid);
      const link = await patient.collection('family').doc(callerUid).get();
      if (!link.exists || link.data().status !== 'active') {
        return res.status(403).json({ success: false, error: 'NOT_LINKED', message: 'You are not approved to send reminders to this person.' });
      }
      const from = String(link.data().caregiverName || '').trim() || 'Family';

      const devices = await patient.collection('devices').get();
      const tokens = devices.docs.map((d) => d.id);
      if (tokens.length === 0) {
        return res.status(200).json({ success: true, delivered: 0 });
      }

      const result = await deps.sendPush(tokens, { title: from, body: text }, { type: 'family_reminder', fromUid: callerUid });
      // Forget tokens of uninstalled apps so they are not tried again.
      (result.responses || []).forEach((r, i) => {
        if (!r.success && r.error && DEAD_TOKEN_CODES.has(r.error.code)) {
          patient.collection('devices').doc(tokens[i]).delete().catch(() => {});
        }
      });
      return res.status(200).json({ success: true, delivered: result.successCount || 0 });
    } catch (err) {
      console.error('[Family] remind failed:', err.message);
      return res.status(500).json({ success: false, error: 'REMIND_FAILED', message: 'Could not send the reminder.' });
    }
  });

  return router;
}

module.exports = { createFamilyRouter, DEFAULT_MESSAGE };
