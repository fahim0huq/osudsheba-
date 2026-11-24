/**
 * AppsPro Webhook Handler
 * Verifies raw-body HMAC-SHA256 signature, enforces timestamp freshness,
 * guarantees idempotency, and reconciles subscription lifecycle events.
 */

const crypto = require('crypto');
const { SubscriptionService } = require('../services/subscription.service');
const { maskPhone } = require('../services/appspro.service');

const TIMESTAMP_TOLERANCE_SECONDS = 300; // 5 minutes

/**
 * Constant-time string comparison to protect against timing attacks
 */
function timingSafeCompare(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

/**
 * AppsPro Webhook Request Handler
 * NOTE: Must be mounted with express.raw({ type: 'application/json' })
 */
async function handleAppsProWebhook(req, res) {
  try {
    const rawBody = req.body;
    if (!rawBody || !Buffer.isBuffer(rawBody)) {
      console.error('[Webhook] Raw body is missing or not a Buffer.');
      return res.status(400).json({
        success: false,
        error: 'RAW_BODY_REQUIRED',
        message: 'Webhook endpoint requires raw body buffer for HMAC verification.',
      });
    }

    // 1. Extract required headers (case-insensitive)
    const timestamp = req.headers['x-timestamp'];
    const bodySha256 = req.headers['x-body-sha256'];
    const signature = req.headers['x-signature'];
    const eventType = req.headers['x-event-type'];
    const eventId = req.headers['x-event-id'];

    if (!timestamp || !bodySha256 || !signature) {
      console.warn('[Webhook] Rejected request: missing required signature headers.');
      return res.status(401).json({
        success: false,
        error: 'SIGNATURE_HEADERS_MISSING',
        message: 'Required verification headers (X-Timestamp, X-Body-Sha256, X-Signature) missing.',
      });
    }

    // 2. Validate timestamp freshness (within 5 minutes)
    const nowSeconds = Math.floor(Date.now() / 1000);
    let parsedTs = parseInt(timestamp, 10);
    if (parsedTs > 1e11) {
      // Milliseconds provided, convert to seconds
      parsedTs = Math.floor(parsedTs / 1000);
    }

    if (isNaN(parsedTs) || Math.abs(nowSeconds - parsedTs) > TIMESTAMP_TOLERANCE_SECONDS) {
      console.warn(`[Webhook] Rejected request: timestamp expired or drifted. Server=${nowSeconds}, Header=${parsedTs}`);
      return res.status(401).json({
        success: false,
        error: 'TIMESTAMP_OUT_OF_RANGE',
        message: 'Request timestamp is expired or outside the allowed 5-minute window.',
      });
    }

    // 3. Verify Body SHA256
    const calculatedBodySha256 = crypto.createHash('sha256').update(rawBody).digest('hex');
    if (!timingSafeCompare(calculatedBodySha256, bodySha256)) {
      console.warn('[Webhook] Rejected request: body SHA256 mismatch.');
      return res.status(401).json({
        success: false,
        error: 'BODY_HASH_MISMATCH',
        message: 'Calculated body SHA256 does not match X-Body-Sha256 header.',
      });
    }

    // 4. Verify HMAC-SHA256 Signature over <timestamp>.<raw_body>
    const signingSecret = process.env.APPSPRO_WEBHOOK_SECRET || process.env.APPSPRO_SECRET_KEY;
    if (!signingSecret) {
      console.error('[Webhook] APPSPRO_WEBHOOK_SECRET and APPSPRO_SECRET_KEY are not configured!');
      return res.status(500).json({
        success: false,
        error: 'WEBHOOK_SECRET_NOT_CONFIGURED',
        message: 'Webhook signing secret is not configured on the server.',
      });
    }

    // AppsPro signs "<X-Timestamp>." followed by the exact raw bytes, so the bytes are
    // concatenated as-is (never decoded and re-encoded).
    const payloadToSign = Buffer.concat([Buffer.from(`${timestamp}.`, 'utf8'), rawBody]);
    const calculatedHmac = crypto.createHmac('sha256', signingSecret).update(payloadToSign).digest('hex');

    if (!timingSafeCompare(calculatedHmac, signature)) {
      console.warn('[Webhook] Rejected request: HMAC signature verification failed.');
      return res.status(401).json({
        success: false,
        error: 'INVALID_SIGNATURE',
        message: 'HMAC signature verification failed.',
      });
    }

    // 5. Parse JSON payload AFTER verification
    let payload;
    try {
      payload = JSON.parse(rawBody.toString('utf8'));
    } catch (parseErr) {
      console.error('[Webhook] Failed to parse JSON payload:', parseErr.message);
      return res.status(400).json({
        success: false,
        error: 'INVALID_JSON',
        message: 'Payload could not be parsed as valid JSON.',
      });
    }

    const effectiveEventId = eventId || payload.event_id || payload.id || `evt_${Date.now()}`;
    const effectiveEventType = eventType || payload.event_type || payload.type || 'unknown';

    console.log(`[Webhook] Validated webhook: ID=${effectiveEventId}, Type=${effectiveEventType}`);

    // 6. Idempotency Check
    const alreadyProcessed = await SubscriptionService.hasWebhookEventBeenProcessed(effectiveEventId);
    if (alreadyProcessed) {
      console.log(`[Webhook] Event ${effectiveEventId} was already processed. Returning HTTP 200 (idempotent).`);
      return res.status(200).json({
        success: true,
        duplicate: true,
        message: 'Event has already been processed.',
      });
    }

    // Record receipt of the event
    await SubscriptionService.recordWebhookEvent(effectiveEventId, {
      eventType: effectiveEventType,
      occurredAt: payload.occurred_at || payload.created_at || new Date().toISOString(),
      applicationId: payload.application_id || payload.app_id || null,
      externalUserId: payload.external_user_id || payload.data?.external_user_id || null,
      subscriberId: payload.subscriber_id || payload.data?.subscriber_id || null,
      processingStatus: 'received',
      payloadMetadata: {
        eventType: effectiveEventType,
        status: payload.data?.status || payload.status,
      },
    });

    // 7. Process Lifecycle & Inbound Events
    try {
      await processEvent(effectiveEventType, payload);
    } catch (procErr) {
      // Recorded as failed (not processed), so AppsPro's retry of this same X-Event-Id is
      // processed again instead of being skipped as a duplicate.
      await SubscriptionService.recordWebhookEvent(effectiveEventId, {
        eventType: effectiveEventType,
        processingStatus: 'failed',
      });
      throw procErr;
    }

    // Mark event as processed
    await SubscriptionService.recordWebhookEvent(effectiveEventId, {
      eventType: effectiveEventType,
      processingStatus: 'processed',
    });

    return res.status(200).json({
      success: true,
      processed: true,
      eventId: effectiveEventId,
    });
  } catch (err) {
    console.error('[Webhook] Unhandled error during webhook processing:', err);
    return res.status(500).json({
      success: false,
      error: 'WEBHOOK_PROCESSING_FAILED',
      message: 'Internal server error while processing webhook.',
    });
  }
}

/**
 * Route event types to specialized processors
 */
async function processEvent(eventType, payload) {
  const data = payload.data || payload;
  const externalUserId = data.external_user_id || payload.external_user_id;
  const subscriberId = data.subscriber_id || payload.subscriber_id || data.id;
  const phone = data.phone || payload.phone;

  // Find target Firebase UID
  let targetUid = externalUserId;
  if (!targetUid && subscriberId) {
    const existing = await SubscriptionService.findSubscriptionBySubscriberId(subscriberId);
    if (existing) {
      targetUid = existing.uid;
    }
  }

  if (!targetUid && (eventType.startsWith('subscriber.'))) {
    console.warn(`[Webhook] Unmatched subscription event (${eventType}): no external_user_id or matching subscriber ID found.`);
    return;
  }

  const now = new Date().toISOString();

  switch (eventType) {
    // The AppsPro dashboard describes subscriber.created as "when user requests OTP" (the docs
    // say REGISTERED), so the event name alone never grants premium: the subscriber's own
    // status decides. subscriber.verified ("user completes subscription") and
    // subscriber.reactivated are confirmations, so they grant when no status is sent.
    case 'subscriber.created':
    case 'subscriber.verified':
    case 'subscriber.reactivated': {
      const sentStatus = data.status || data.subscription_status || null;
      if (!sentStatus && eventType === 'subscriber.created') {
        console.log(`[Webhook] ${eventType} without a status for user ${targetUid}: not granting (OTP requested only).`);
        break;
      }
      const status = sentStatus || 'active';
      const { status: normalized, entitlementActive } = SubscriptionService.normalizeStatus(status);
      if (eventType === 'subscriber.created' && !entitlementActive) {
        // Do not overwrite a working plan with an early "pending" from a new OTP request.
        const existing = await SubscriptionService.getSubscription(targetUid);
        if (existing && existing.entitlementActive) {
          console.log(`[Webhook] ${eventType} (${status}) ignored for ${targetUid}: already active.`);
          break;
        }
      }
      console.log(`[Webhook] ${eventType} (${status} -> ${normalized}) for user ${targetUid}`);
      await SubscriptionService.saveSubscription(targetUid, {
        status,
        appsproSubscriberId: subscriberId,
        ...(phone ? { phone } : {}),
        frequency: data.frequency || 'daily',
        ...(entitlementActive ? { subscribedAt: data.subscribed_at || data.created_at || now, cancelledAt: null } : {}),
      });
      break;
    }

    case 'subscriber.cancelled': {
      console.log(`[Webhook] Subscription CANCELLED for user ${targetUid}`);
      await SubscriptionService.saveSubscription(targetUid, {
        status: 'cancelled',
        cancelledAt: data.cancelled_at || now,
      });
      break;
    }

    case 'sms.received': {
      // data is the raw BDApps MO payload: { applicationId, sourceAddress: "tel:880...", message, ... }
      console.log(`[Webhook] Inbound SMS received from ${maskPhone(data.sourceAddress || phone)}`);
      // Ingestion path preserved; clean boundary for future SMS logic
      break;
    }

    case 'ussd.received': {
      console.log(`[Webhook] Inbound USSD received from ${maskPhone(data.sourceAddress || phone)}`);
      // Ingestion path preserved; clean boundary for future USSD logic
      break;
    }

    default: {
      // Generic subscriber.<status> handling
      if (eventType.startsWith('subscriber.')) {
        const statusName = eventType.replace('subscriber.', '');
        console.log(`[Webhook] Generic subscriber status update (${statusName}) for user ${targetUid}`);
        await SubscriptionService.saveSubscription(targetUid, {
          status: statusName,
          appsproSubscriberId: subscriberId,
        });
      } else {
        console.log(`[Webhook] Unhandled event type: ${eventType}. Logged safely.`);
      }
      break;
    }
  }
}

module.exports = {
  handleAppsProWebhook,
  timingSafeCompare,
  processEvent, // tests
};
