/**
 * Subscription Database & State Management Service
 * Manages persistent storage in Firestore (with automatic local fallback for dev/testing)
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');
const { maskPhone } = require('./appspro.service');

// Initialize Firestore if available
let firestoreDb = null;
let useLocalFallback = false;

try {
  let app;
  try {
    const { getApps, initializeApp } = require('firebase-admin/app');
    const apps = getApps();
    if (!apps || apps.length === 0) {
      app = initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID || 'osudsheba-7b88a',
      });
    } else {
      app = apps[0];
    }
  } catch {
    if (!admin.apps || admin.apps.length === 0) {
      app = admin.initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID || 'osudsheba-7b88a',
      });
    } else {
      app = admin.apps[0];
    }
  }

  // Only attempt Firestore if Google Application Default Credentials or service account is configured
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.FIREBASE_CONFIG) {
    const { getFirestore } = require('firebase-admin/firestore');
    firestoreDb = getFirestore(app);
  } else {
    // In local sandbox/dev without explicit ADC, seamlessly use local persistent store
    useLocalFallback = true;
  }
} catch (err) {
  console.warn('[SubscriptionService] Firestore initialization deferred or unavailable:', err.message);
  useLocalFallback = true;
}

if (useLocalFallback) {
  require('./production_guard').assertLiveConfig(
    'No Firestore credentials, so subscriptions would be kept in a JSON file that Render wipes on every restart.',
    'Set GOOGLE_APPLICATION_CREDENTIALS to the Firebase service-account file (a Render secret file).',
  );
}

// Local file store setup for dev/sandbox fallback
const DATA_DIR = process.env.SUBSCRIPTION_DATA_DIR
  ? path.resolve(process.env.SUBSCRIPTION_DATA_DIR)
  : path.join(__dirname, '..', 'data');
const SUBS_FILE = path.join(DATA_DIR, 'subscriptions.json');
const EVENTS_FILE = path.join(DATA_DIR, 'webhook_events.json');

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
  if (!fs.existsSync(SUBS_FILE)) {
    fs.writeFileSync(SUBS_FILE, JSON.stringify({}), 'utf8');
  }
  if (!fs.existsSync(EVENTS_FILE)) {
    fs.writeFileSync(EVENTS_FILE, JSON.stringify({}), 'utf8');
  }
}

function readLocalData(file) {
  try {
    ensureDataDir();
    const content = fs.readFileSync(file, 'utf8');
    return JSON.parse(content || '{}');
  } catch (err) {
    console.error(`[SubscriptionService] Failed to read ${file}:`, err.message);
    return {};
  }
}

function writeLocalData(file, data) {
  try {
    ensureDataDir();
    fs.writeFileSync(file, JSON.stringify(data, null, 2), 'utf8');
  } catch (err) {
    console.error(`[SubscriptionService] Failed to write ${file}:`, err.message);
  }
}

/**
 * Normalizes an external status to internal subscription state
 * Note: AppsPro returns valid: true when OTP matches, but pending / INITIAL CHARGING PENDING
 * means carrier charging has not succeeded (e.g. insufficient airtime balance).
 * Only confirmed active/registered status grants active entitlement.
 */
function normalizeStatus(rawStatus) {
  if (!rawStatus || typeof rawStatus !== 'string') {
    return { status: 'unknown', entitlementActive: false };
  }
  const s = rawStatus.toLowerCase().trim();

  if (s === 'active' || s === 'registered' || s === 'subscribed' || s === 'success') {
    return { status: 'active', entitlementActive: true };
  }
  if (s === 'pending' || s.includes('pending')) {
    return { status: 'pending', entitlementActive: false };
  }
  if (s === 'cancelled' || s === 'unregistered' || s === 'deactivated') {
    return { status: 'cancelled', entitlementActive: false };
  }
  if (s === 'inactive' || s === 'expired') {
    return { status: 'inactive', entitlementActive: false };
  }

  // Safe fail-closed for any unrecognized status
  return { status: s, entitlementActive: false };
}

class SubscriptionService {
  /**
   * Normalize an incoming status string
   */
  static normalizeStatus(status) {
    return normalizeStatus(status);
  }

  /**
   * Get subscription record by Firebase UID
   */
  static async getSubscription(uid) {
    if (!uid) return null;

    let record = null;
    if (!useLocalFallback && firestoreDb) {
      try {
        const docRef = firestoreDb.collection('subscriptions').doc(uid);
        const docSnap = await docRef.get();
        if (docSnap.exists) {
          record = docSnap.data();
        }
      } catch (err) {
        console.warn(`[SubscriptionService] Firestore read failed (${err.message}), falling back to local store.`);
        useLocalFallback = true;
      }
    }

    if (!record) {
      const localSubs = readLocalData(SUBS_FILE);
      record = localSubs[uid] || null;
    }

    if (record) {
      const { status, entitlementActive } = normalizeStatus(record.status || record.originalStatus);
      record.status = status;
      record.entitlementActive = entitlementActive;
    }
    return record;
  }

  /**
   * Find a subscription by AppsPro subscriber ID or phone (for webhook reconciliation)
   */
  /**
   * Find an active subscription by phone number
   */
  static async findSubscriptionByPhone(phone) {
    if (!phone) return null;
    let cleanPhone = String(phone).replace(/\D/g, '');
    if (cleanPhone.startsWith('880')) {
      cleanPhone = cleanPhone.substring(2);
    } else if (!cleanPhone.startsWith('0') && cleanPhone.length === 10) {
      cleanPhone = '0' + cleanPhone;
    }

    let record = null;
    if (!useLocalFallback && firestoreDb) {
      try {
        const snapshot = await firestoreDb.collection('subscriptions')
          .where('phone', '==', cleanPhone)
          .limit(1)
          .get();
        if (!snapshot.empty) {
          record = snapshot.docs[0].data();
        }
      } catch (err) {
        console.warn(`[SubscriptionService] Firestore phone query failed (${err.message}), trying local fallback.`);
        useLocalFallback = true;
      }
    }

    if (!record) {
      const localSubs = readLocalData(SUBS_FILE);
      for (const r of Object.values(localSubs)) {
        if (r.phone === cleanPhone) {
          record = r;
          break;
        }
      }
    }

    if (record) {
      const { status, entitlementActive } = normalizeStatus(record.status || record.originalStatus);
      record.status = status;
      record.entitlementActive = entitlementActive;
    }
    return record;
  }

  static async findSubscriptionBySubscriberId(subscriberId) {
    if (!subscriberId) return null;

    let record = null;
    if (!useLocalFallback && firestoreDb) {
      try {
        const snapshot = await firestoreDb.collection('subscriptions')
          .where('appsproSubscriberId', '==', subscriberId)
          .limit(1)
          .get();
        if (!snapshot.empty) {
          record = snapshot.docs[0].data();
        } else {
          const localSnapshot = await firestoreDb.collection('subscriptions')
            .where('appsproLocalSubscriberId', '==', subscriberId)
            .limit(1)
            .get();
          if (!localSnapshot.empty) {
            record = localSnapshot.docs[0].data();
          }
        }
      } catch (err) {
        console.warn(`[SubscriptionService] Firestore query failed (${err.message}), trying local fallback.`);
        useLocalFallback = true;
      }
    }

    if (!record) {
      const localSubs = readLocalData(SUBS_FILE);
      for (const r of Object.values(localSubs)) {
        if (r.appsproSubscriberId === subscriberId || r.appsproLocalSubscriberId === subscriberId) {
          record = r;
          break;
        }
      }
    }

    if (record) {
      const { status, entitlementActive } = normalizeStatus(record.status || record.originalStatus);
      record.status = status;
      record.entitlementActive = entitlementActive;
    }
    return record;
  }

  /**
   * Upsert a subscription record for a Firebase UID
   */
  static async saveSubscription(uid, data) {
    if (!uid) throw new Error('Cannot save subscription without a valid UID');

    const now = new Date().toISOString();
    const existing = await this.getSubscription(uid) || {};

    const rawStatus = data.status || existing.status || 'unknown';
    const { status, entitlementActive } = normalizeStatus(rawStatus);

    const subscriptionRecord = {
      uid,
      externalUserId: uid,
      appsproSubscriberId: data.appsproSubscriberId || existing.appsproSubscriberId || null,
      appsproLocalSubscriberId: data.appsproLocalSubscriberId || existing.appsproLocalSubscriberId || null,
      phone: data.phone || existing.phone || null,
      phoneMasked: data.phone ? maskPhone(data.phone) : (existing.phoneMasked || null),
      status,
      originalStatus: rawStatus,
      entitlementActive,
      frequency: data.frequency || existing.frequency || 'daily',
      subscriptionType: data.subscriptionType || existing.subscriptionType || 'carrier_billing',
      subscribedAt: data.subscribedAt || existing.subscribedAt || (entitlementActive ? now : null),
      cancelledAt: data.cancelledAt || (status === 'cancelled' ? now : null),
      lastVerifiedAt: now,
      source: 'appspro',
      isSandbox: process.env.APPSPRO_ENV === 'sandbox' || Boolean(data.isSandbox),
      createdAt: existing.createdAt || now,
      updatedAt: now,
    };

    if (!useLocalFallback && firestoreDb) {
      try {
        const docRef = firestoreDb.collection('subscriptions').doc(uid);
        await docRef.set(subscriptionRecord, { merge: true });
      } catch (err) {
        console.warn(`[SubscriptionService] Firestore save failed (${err.message}), saving to local store.`);
        useLocalFallback = true;
      }
    }

    const localSubs = readLocalData(SUBS_FILE);
    localSubs[uid] = subscriptionRecord;
    writeLocalData(SUBS_FILE, localSubs);

    console.log(`[SubscriptionService] Saved subscription for ${uid}: status=${status}, entitlementActive=${entitlementActive}`);
    return subscriptionRecord;
  }

  /**
   * Permanently delete a user's subscription record (in-app account deletion).
   * Throws if Firestore is in use and the delete fails, so the caller never reports
   * "deleted" while the record (with the user's phone number) still exists.
   */
  static async deleteSubscription(uid) {
    if (!uid) throw new Error('Cannot delete subscription without a valid UID');

    if (!useLocalFallback && firestoreDb) {
      await firestoreDb.collection('subscriptions').doc(uid).delete();
    }

    const localSubs = readLocalData(SUBS_FILE);
    if (localSubs[uid]) {
      delete localSubs[uid];
      writeLocalData(SUBS_FILE, localSubs);
    }
    console.log(`[SubscriptionService] Deleted subscription record for ${uid}`);
  }

  /**
   * Deletes the user's medicines / dose-history backup (users/{uid} and everything under
   * it), written by the app's cloud backup. Admin SDK, so it works whatever the rules say.
   * No-op when Firestore is not configured (local tests): there is no backup to delete.
   */
  static async deleteUserBackup(uid) {
    if (!uid) throw new Error('Cannot delete backup without a valid UID');
    if (useLocalFallback || !firestoreDb) return;
    await firestoreDb.recursiveDelete(firestoreDb.collection('users').doc(uid));
    console.log(`[SubscriptionService] Deleted cloud backup for ${uid}`);
  }

  /**
   * Check if a webhook event has already been processed (Idempotency)
   */
  static async hasWebhookEventBeenProcessed(eventId) {
    if (!eventId) return false;

    if (!useLocalFallback && firestoreDb) {
      try {
        const docRef = firestoreDb.collection('appspro_webhook_events').doc(eventId);
        const docSnap = await docRef.get();
        if (docSnap.exists) {
          const data = docSnap.data();
          return data.processingStatus === 'processed';
        }
      } catch (err) {
        console.warn(`[SubscriptionService] Firestore webhook event check failed:`, err.message);
        useLocalFallback = true;
      }
    }

    const localEvents = readLocalData(EVENTS_FILE);
    return localEvents[eventId]?.processingStatus === 'processed';
  }

  /**
   * Record and update a webhook event log
   */
  static async recordWebhookEvent(eventId, eventData) {
    if (!eventId) return;

    const now = new Date().toISOString();
    const record = {
      eventId,
      eventType: eventData.eventType || 'unknown',
      occurredAt: eventData.occurredAt || now,
      applicationId: eventData.applicationId || process.env.APPSPRO_APP_ID || null,
      externalUserId: eventData.externalUserId || null,
      subscriberId: eventData.subscriberId || null,
      receivedAt: eventData.receivedAt || now,
      processedAt: now,
      processingStatus: eventData.processingStatus || 'processed',
      payloadMetadata: eventData.payloadMetadata || {},
    };

    if (!useLocalFallback && firestoreDb) {
      try {
        await firestoreDb.collection('appspro_webhook_events').doc(eventId).set(record, { merge: true });
      } catch (err) {
        console.warn(`[SubscriptionService] Firestore recordWebhookEvent failed:`, err.message);
        useLocalFallback = true;
      }
    }

    const localEvents = readLocalData(EVENTS_FILE);
    localEvents[eventId] = record;
    writeLocalData(EVENTS_FILE, localEvents);
  }
}

module.exports = {
  SubscriptionService,
  normalizeStatus,
};
