# OsudSheba — AppsPro & BDApps Subscription Integration

Technical reference for the AppsPro (BDApps direct carrier billing) subscription in OsudSheba.
Source of truth for every AppsPro endpoint and field: https://appspro.dev/docs (checked 2026-11-24).

---

## 1. Architecture

OsudSheba is **premium-only**: every non-public screen needs an active carrier-billing
subscription (Robi / Airtel through BDApps). The app never talks to AppsPro directly; it talks to
our server with a Firebase ID token, and the server holds the AppsPro secret key. This is the
"route through your own server" pattern from the AppsPro docs.

```
Flutter app ──(Bearer <Firebase ID token>)──▶ OsudSheba server (Render)
                                                │  Bearer <APPSPRO_SECRET_KEY>
                                                ▼
                                    api.appspro.dev/api/v1/sdk/*
                                                │
                                    BDApps (Robi / Airtel DCB)
                                                │ notify callback
AppsPro ──(signed POST, X-Signature)──▶ OsudSheba server /webhooks/appspro
```

---

## 2. AppsPro services: what OsudSheba needs and where it lives

| AppsPro service (docs section) | Needed? | State | Where |
|---|---|---|---|
| Request OTP `POST /sdk/otp/request` (+ `external_user_id`) | Yes | Done | `server/services/appspro.service.js` `requestOtp`; route `POST /subscription/otp/request` |
| Verify OTP `POST /sdk/otp/verify` (unlock from the reply, not the webhook) | Yes | Done | `verifyOtp`; route `POST /subscription/otp/verify` |
| Live status by phone `POST /sdk/status` | Yes | Done | `getLiveStatusByPhone`; used by the status re-check in `subscription.controller.js` |
| Verify subscriber `GET /sdk/verify/{subscriber_id}` | Yes | Done | `getSubscriberStatus`; second source for the pending re-check |
| Unsubscribe `POST /sdk/unsubscribe` (success = `S1000` or `UNREGISTERED`) | Yes | Done | `unsubscribe` + `unsubscribeConfirmed`; route `POST /subscription/unsubscribe` |
| App info `GET /sdk/app-info` (pricing list, `disclosure_md`) | Yes | Done (Nov 2026: the app now reads the documented `pricing` list and shows the total and disclosure) | `getAppInfo`; `AppPricingInfo` in `lib/core/models/subscription.dart` |
| Privacy scrub `DELETE /sdk/subscribers/by-external-id/{id}` | Yes (account deletion) | Done (Nov 2026) | `deleteSubscriberByExternalId`; called by `DELETE /subscription/account` |
| Webhooks: signature, replay window, idempotency, `subscriber.*`, `sms.received`, `ussd.received` | Yes | Done | `server/webhooks/appspro.webhook.js` |
| List subscribers `GET /sdk/subscribers` | Diagnostics only | Done | `testProtectedSubscribers` (startup check, logs status only) |
| Batch verify `POST /sdk/verify/batch` | Optional (reconciler) | Client method only | `verifySubscriberBatch`; no scheduled job (per-request re-check covers it) |
| Direct subscribe `POST /sdk/subscribe` (no OTP) | No | Deliberately not exposed | Docs: trusted server-to-server only; a route would let a user subscribe someone else's number |
| Flutter SDK `appspro_sdk` widgets | No (own UI) | Dependency present, not used | `SubscriptionService.configureNativeSdk` is never called; the app uses its own screens and the server proxy |
| Hosted checkout `/s/{slug}`, WebSDK, `/embed`, `generate-token`, `subscription_token` routes | No | Not used | Docs: a proxying app needs none of the subscription-token routes |
| Sending SMS / charging from our backend | Not available | — | Docs: not part of the public API; use the AppsPro dashboard |
| USSD menus | No | Inbound events are only logged | — |

---

## 3. Environment

### Server (`server/.env` locally, Render environment variables in production)

Key names only; never commit values.

| Key | Purpose |
|---|---|
| `APPSPRO_BASE_URL` | `https://api.appspro.dev/api/v1` |
| `APPSPRO_SECRET_KEY` | SDK Bearer key (`sk_…`); also the webhook HMAC key when no signing secret is set |
| `APPSPRO_PUBLISHABLE_KEY` | `pk_…`, used for `/sdk/app-info` |
| `APPSPRO_WEBHOOK_SECRET` | Webhook signing secret, if one is set in the dashboard |
| `APPSPRO_ENV` | `production` or `sandbox` (sandbox also allows non-Robi/Airtel test numbers) |
| `APPSPRO_ALLOW_SIMULATION` | `true` only for local tests; ignored when `NODE_ENV=production` |
| `NODE_ENV` | `production` on Render |
| `FIREBASE_PROJECT_ID`, `ALLOWED_ORIGINS`, `DIAGNOSTICS_TOKEN` | Firebase project, CORS list, operator-only diagnostics |

> [!CAUTION]
> Never put `APPSPRO_SECRET_KEY` or `APPSPRO_WEBHOOK_SECRET` in Flutter code, assets or Git.
> Only the publishable key may ship in the app.

### Sandbox

AppsPro sandbox keys (dashboard → API & SDK → Sandbox Keys) hit a mock carrier: no SMS, no charges,
OTP always `000000`. The sandbox app and its keys are deleted when the app is published, so
production must use the production keys.

---

## 4. Data

### `subscriptions/{firebaseUid}`

| Field | Description |
|---|---|
| `uid` / `externalUserId` | Firebase UID; sent to AppsPro as `external_user_id` |
| `appsproSubscriberId` | BDApps subscriber id (`tel:880…`) |
| `appsproLocalSubscriberId` | AppsPro `local_subscriber_id` |
| `phone`, `phoneMasked` | The number the OTP went to (never one sent by the app) |
| `status`, `originalStatus` | Normalised (`active`, `pending`, `cancelled`, `inactive`, …) and verbatim |
| `entitlementActive` | `true` only for `active` (see §6 on `pending`) |
| `frequency`, `subscribedAt`, `cancelledAt`, `lastVerifiedAt`, `isSandbox`, `createdAt`, `updatedAt` | |

### `appspro_webhook_events/{X-Event-Id}`

`eventType`, `occurredAt`, `externalUserId`, `subscriberId`, `processingStatus`
(`received` → `processed`, or `failed`), `receivedAt`, `processedAt`, `payloadMetadata`.
Only `processed` counts as a duplicate, so AppsPro's retry of a `failed` event is applied.

---

## 5. Server endpoints (Firebase ID token unless marked public)

Each route is mounted under both `/subscription/*` and `/appspro/*` (the paths the AppsPro proxy
backend expects).

| Route | What it does |
|---|---|
| `GET /status` (alias `GET /subscription`) | `{ success, valid, status, reason, subscription }` (`reason` is `null` when valid). Re-checks an active plan with AppsPro every 15 min and a pending one every 15 s. |
| `GET /app-info` (public) | AppsPro `/sdk/app-info` payload as sent. If AppsPro is unreachable: same shape with `fallback: true`, last known price, no tax total, no disclosure. |
| `POST /otp/request` | Body `{ phone }`. Robi/Airtel only (except sandbox). 6 per 10 min per user. Already-registered numbers are granted only to the Firebase-verified owner. |
| `POST /otp/verify` | Body `{ reference_no, otp }`. Only the account that requested the OTP may verify it. `REGISTERED` → active; charging pending → `pending` (locked, app waits). |
| `POST /unsubscribe` | Cancels at AppsPro; reports cancelled only on `S1000` / `UNREGISTERED`. |
| `DELETE /account` | Refuses (409) while billing runs. Otherwise asks AppsPro to scrub the number (`DELETE /sdk/subscribers/by-external-id/{uid}`, 404 = nothing held), then deletes our record and cloud backup. If the scrub fails: 502 `BILLING_DATA_DELETE_FAILED` and nothing is deleted. |
| `GET /diagnostic` | Hidden unless `DIAGNOSTICS_TOKEN` is set and sent as `x-diagnostics-token`. |

There is no `/subscribe` route (OTP-free subscribe is server-to-server only).
`/web-subscription/*` serves the website (phone + OTP, no login); its `app-info` keeps a single
`pricing` object and adds `amount_inclusive` and `disclosure_md` from AppsPro.

`POST /analyze-prescription` was removed in Nov 2026 (scanning runs on the phone).
`requireSubscription` middleware (403 `SUBSCRIPTION_REQUIRED`) remains for any future paid route.

---

## 6. Webhook (`POST /webhooks/appspro`, public, signed)

1. Mounted with `express.raw({ type: 'application/json' })` before `express.json()`.
2. `X-Timestamp` must be within 300 s.
3. `sha256(raw body)` must equal `X-Body-Sha256`.
4. `X-Signature` must equal hex HMAC-SHA256 of `"<X-Timestamp>."` + the **raw bytes**
   (concatenated as bytes, never decoded), keyed with `APPSPRO_WEBHOOK_SECRET`, else `APPSPRO_SECRET_KEY`.
5. Idempotent on `X-Event-Id`.
6. Events:
   - `subscriber.created` / `subscriber.reactivated` (and `subscriber.verified`, which the dashboard
     lists): the subscriber's `data.status` decides. `REGISTERED` grants; a `created` without a status
     or with a pending status never overwrites an active plan.
   - `subscriber.cancelled`: cancelled, premium removed.
   - any other `subscriber.<status>`: stored normalised; unknown statuses fail closed.
   - `sms.received`, `ussd.received`: logged (masked `data.sourceAddress`), nothing else.

**Pending is locked on purpose.** AppsPro's SDK treats `pending` as subscribed. OsudSheba does not:
it waits (polling every 5–15 s) until the operator confirms the charge, so nobody gets premium
without paying. The pending re-check never cancels an attempt.

---

## 7. Flutter app

- `lib/core/services/subscription_service.dart`: HTTP calls to the routes above.
- `lib/core/providers/subscription_provider.dart`: `subscriptionProvider` (Hive cache per uid, then
  server check; reset on logout) and `appPricingInfoProvider`.
- `lib/app/router.dart`: redirect guard sends unentitled users to `/subscription`.
- `SubscriptionScreen`: price and billing period from AppsPro app-info; the tax line shows AppsPro's
  `price_inclusive` total when sent; the BDApps-required `disclosure_md` line is shown as sent
  (English, from AppsPro). Phone → 6-digit OTP with a **120 s** resend wait (AppsPro allows 10 OTP
  SMS per number per hour) → waiting card while the charge is pending.
- Settings: subscription status, masked phone, cancel with confirmation; account deletion cancels first.

---

## 8. Tests

```bash
cd server && npm test        # all offline suites; AppsPro keys are blanked, never contacted
flutter analyze && flutter test
```

Server suites: `subscription`, `web_subscription`, `security`, `family`, `appspro_flow`,
`appspro_docs` (documented contracts: privacy scrub, status `reason`, app-info shape, raw-byte
HMAC, failed-event retry). `test/test_live_appspro.js` calls the real API and is never run by `npm test`.
Flutter: `test/app_pricing_info_test.dart` covers the app-info pricing list.

---

## 9. Operator checklist (outside the code)

**BDApps developer portal** (developer.bdapps.com)
- SMS MO URL `https://api.appspro.dev/bdapps/sms`, USSD URL `https://api.appspro.dev/bdapps/ussd`,
  subscription notify URL `https://api.appspro.dev/bdapps/notify`, delivery report URL
  `https://api.appspro.dev/bdapps/report`.
- Whitelist AppsPro's outbound IP `217.15.160.79`.
- Ask BDApps support to **activate the Unsubscription, Subscriber Status and SMS APIs** for the
  app. Until then unsubscribe and `/sdk/status` fail (the pending re-check falls back to `/sdk/verify`).

**AppsPro dashboard**
- Webhook URL `https://osudsheba.onrender.com/webhooks/appspro`; events `subscriber.created`,
  `subscriber.reactivated`, `subscriber.cancelled`, the other `subscriber.*` statuses, and
  optionally `sms.received` / `ussd.received`.
- If a webhook signing secret is set, put the same value in `APPSPRO_WEBHOOK_SECRET` on Render.
- Production keys on Render (sandbox keys are deleted at publish).

**Rotating the secret key**: regenerate in the dashboard (shown once), update `APPSPRO_SECRET_KEY`
on Render, redeploy. Never commit keys.
