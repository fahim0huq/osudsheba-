# OsudSheba — AppsPro & BDApps Subscription System Integration

This document serves as the complete technical reference for the AppsPro (BDApps Direct Carrier Billing) subscription integration for OsudSheba.

---

## 1. Architecture Overview

OsudSheba is a **premium-only** application with zero free tier. Users must hold an active or pending carrier billing subscription (Robi / Airtel via BDApps) to access any application features.

```
                  ┌────────────────────────────────────────┐
                  │            OSUDSHEBA FLUTTER           │
                  │   - Riverpod (subscriptionProvider)    │
                  │   - GoRouter Centralized Redirect Guard│
                  │   - AppStartupGate Gating              │
                  │   - Bilingual Subscription Screen      │
                  └──────────────────┬─────────────────────┘
                                     │ Authorization: Bearer <Firebase ID Token>
                                     ▼
                  ┌────────────────────────────────────────┐
                  │            OSUDSHEBA BACKEND           │
                  │   - Firebase Admin Auth Middleware     │
                  │   - requireSubscription Middleware     │
                  │   - AppsPro Service & Proxy Controller │
                  │   - Raw-Body HMAC-SHA256 Webhook Engine│
                  │   - Persistent Firestore Database      │
                  └─────────┬───────────────────▲──────────┘
      Authorization: Bearer │                   │ Signed HTTPS POST
         <APPSPRO_SECRET_KEY│                   │ X-Signature / HMAC
                            ▼                   │
                  ┌─────────────────────────────┴──────────┐
                  │                 APPSPRO                │
                  │         api.appspro.dev/api/v1         │
                  └──────────────────┬─────────────────────┘
                                     │
                                     ▼
                  ┌────────────────────────────────────────┐
                  │                 BDAPPS                 │
                  │           Robi / Airtel DCB            │
                  └────────────────────────────────────────┘
```

---

## 2. Environment Configuration

### Backend (`server/.env`)

All AppsPro credentials reside strictly on the server:

```ini
# Server Port
PORT=3000

# Firebase Project Configuration
FIREBASE_PROJECT_ID=osudsheba-7b88a
ALLOW_MOCK_AUTH=true

# AppsPro Configuration (BDApps Direct Carrier Billing)
APPSPRO_BASE_URL=https://api.appspro.dev/api/v1
APPSPRO_PUBLISHABLE_KEY=pk_live_your_publishable_key
APPSPRO_SECRET_KEY=sk_live_your_secret_key
APPSPRO_APP_ID=app_your_appspro_app_id
APPSPRO_WEBHOOK_SECRET=whsec_your_webhook_signing_secret
APPSPRO_ENV=production
```

> [!CAUTION]
> **Strict Security Rule**: Never put `APPSPRO_SECRET_KEY` or `APPSPRO_WEBHOOK_SECRET` in Flutter code, assets, `pubspec.yaml`, or Git. The client communicates solely with the OsudSheba backend using Firebase ID tokens.

---

## 3. Database Structure

### `subscriptions/{firebaseUid}`
Maintains the authoritative subscription entitlement per user:

| Field | Type | Description |
|---|---|---|
| `uid` | `string` | Firebase Auth UID (authoritative identity) |
| `externalUserId` | `string` | Maps 1:1 to Firebase UID in AppsPro |
| `appsproSubscriberId` | `string \| null` | BDApps/AppsPro subscriber identifier |
| `appsproLocalSubscriberId`| `string \| null` | AppsPro internal entity ID |
| `phone` | `string \| null` | Normalized subscriber phone (01XXXXXXXXX) |
| `phoneMasked` | `string \| null` | Masked phone for safe display (01812***678) |
| `status` | `string` | Normalized status (`active`, `pending`, `cancelled`, etc.) |
| `originalStatus` | `string` | Verbatim status reported by AppsPro |
| `entitlementActive` | `boolean` | `true` for active & pending; `false` otherwise |
| `frequency` | `string` | Billing cadence (`daily`) |
| `subscriptionType` | `string` | `carrier_billing` |
| `subscribedAt` | `timestamp` | First subscribed timestamp |
| `cancelledAt` | `timestamp` | Cancellation timestamp |
| `lastVerifiedAt` | `timestamp` | Last verification timestamp |
| `source` | `string` | `"appspro"` |
| `isSandbox` | `boolean` | `true` when running under sandbox credentials |
| `createdAt` | `timestamp` | Record creation time |
| `updatedAt` | `timestamp` | Record update time |

### `appspro_webhook_events/{eventId}`
Enforces idempotency and provides an audit trail:

| Field | Type | Description |
|---|---|---|
| `eventId` | `string` | AppsPro `X-Event-Id` |
| `eventType` | `string` | `subscriber.created`, `subscriber.cancelled`, etc. |
| `occurredAt` | `timestamp` | Event timestamp from payload |
| `externalUserId` | `string` | Associated user UID |
| `subscriberId` | `string` | Associated subscriber identifier |
| `processingStatus` | `string` | `processed` \| `failed` \| `received` |
| `receivedAt` | `timestamp` | Receipt timestamp |
| `processedAt` | `timestamp` | Processing completion timestamp |
| `payloadMetadata` | `object` | Safe metadata (excluding raw secrets) |

---

## 4. Backend Endpoints

### User Subscription Routes (Authenticated via Firebase ID Token)

1. **`GET /subscription/status`** (and alias `GET /appspro/subscription`):
   - Header: `Authorization: Bearer <Firebase ID Token>`
   - Returns entitlement state:
     ```json
     {
       "success": true,
       "valid": true,
       "subscription": {
         "status": "active",
         "entitlementActive": true,
         "frequency": "daily",
         "phoneMasked": "01812***678",
         "subscribedAt": "2026-09-04T09:00:00.000Z"
       }
     }
     ```

2. **`GET /subscription/app-info`** (and alias `GET /appspro/app-info`):
   - Returns pricing, supported carriers (`Robi`, `Airtel`), and statutory tax disclosures.

3. **`POST /subscription/otp/request`** (and alias `POST /appspro/otp/request`):
   - Body: `{"phone": "01812345678"}`
   - Rate limited to 6 requests / 10 minutes per user.
   - Forwards request to AppsPro with `external_user_id = req.user.uid`.
   - Returns `{ "success": true, "reference_no": "..." }`.

4. **`POST /subscription/otp/verify`** (and alias `POST /appspro/otp/verify`):
   - Body: `{"referenceNo": "...", "otp": "..."}`
   - On successful AppsPro verification (`REGISTERED` / `ACTIVE` / `PENDING`):
     - Immediately persists subscription in Firestore.
     - Sets `entitlementActive = true`.
     - Returns `{ "success": true, "valid": true, "entitlementActive": true }`.
     - **Note**: Entitlement is granted immediately; the app does NOT wait for the webhook.

5. **`POST /subscription/unsubscribe`** (and alias `POST /appspro/unsubscribe`):
   - Authenticated user.
   - Queries stored subscription; calls AppsPro to cancel subscription for the verified phone.
   - Updates record to `cancelled`, `entitlementActive = false`.

### Premium API Access Control

- **`POST /analyze-prescription`** (removed in Nov 2026: scanning now runs on the phone, so this
  route and its Replicate/Gemini call no longer exist; kept here as an example of the gating pattern):
  Protected by `requireSubscription` middleware.
  Unentitled users receive `HTTP 403`:
  ```json
  {
    "success": false,
    "error": "SUBSCRIPTION_REQUIRED",
    "message": "An active OsudSheba subscription is required to access this feature."
  }
  ```

---

## 5. Webhook Implementation (`POST /webhooks/appspro`)

The AppsPro webhook endpoint is public (unauthenticated by Firebase) and secured via raw-body cryptographic signature verification:

1. **Raw Body Ingestion**: Express route is mounted with `express.raw({ type: 'application/json' })` BEFORE `express.json()`.
2. **Timestamp Verification**: Rejects requests where `|Date.now() - X-Timestamp| > 300 seconds` with `HTTP 401`.
3. **Body SHA256 Verification**: Computes `crypto.createHash('sha256').update(rawBody).digest('hex')` and validates against `X-Body-Sha256` using `crypto.timingSafeEqual`.
4. **HMAC-SHA256 Verification**: Computes HMAC over `<timestamp>.<raw_body>` using `APPSPRO_WEBHOOK_SECRET` (or `APPSPRO_SECRET_KEY`) and validates against `X-Signature` using `crypto.timingSafeEqual`.
5. **Idempotency Check**: Checks `appspro_webhook_events/{eventId}`. Duplicate deliveries return `HTTP 200 { duplicate: true }` without re-running state mutations.
6. **Event Dispatch**:
   - `subscriber.created`: sets `active`, `entitlementActive = true`.
   - `subscriber.reactivated`: sets `active`, `entitlementActive = true`.
   - `subscriber.cancelled`: sets `cancelled`, `entitlementActive = false`.
   - `subscriber.<status>`: normalized gracefully; unknown states fail closed without crashing.
   - `sms.received` & `ussd.received`: logged and recorded safely.

---

## 6. Flutter Architecture & Gating

### Centralized Subscription Provider (`subscriptionProvider`)
- Tracks `loading`, `active`, `pending`, `notSubscribed`, `cancelled`, `inactive`, `error`.
- Optimistically caches entitlement in Hive (`subscription_cache_$uid`) to avoid UI screen flicker on app launch, then immediately validates against backend.
- Automatically resets and purges state when the user logs out.

### Startup & Router Protection
1. **`AppStartupGate`**:
   - Evaluates authentication first.
   - If authenticated, waits for subscription verification.
   - If unentitled (`notSubscribed`, `cancelled`, `inactive`), routes directly to `/subscription`.
   - If entitled, routes to main app (`/home` or profile setup).
2. **`GoRouter` Redirect Guard**:
   - Intercepts any direct navigation or deep link to premium routes (`/home`, `/medicines`, `/upload-prescription`, `/adherence`, `/caregiver`, `/settings`, etc.).
   - Automatically redirects unentitled users to `/subscription`.

### UI Screens
- **`SubscriptionScreen`**:
  - Medical-grade design matching OsudSheba theme (`AppColors`).
  - Highlights premium features (AI Prescription Scanner, Reminders, Voice TTS, Caregiver alerts).
  - Dynamic pricing (BDT 2.00 / day).
  - Phone entry (Robi / Airtel BDApps carrier billing).
  - 6-digit OTP verification with countdown timer and resend.
  - Immediate entitlement unlock upon verification.
- **`SettingsScreen`**:
  - "সাবস্ক্রিপশন ও প্রিমিয়াম" (Subscription & Premium) tile.
  - Displays plan details, status badge, masked phone, subscribed date.
  - "সাবস্ক্রিপশন বাতিল করুন" (Cancel Subscription) with confirmation modal.

---

## 7. Testing & Sandbox Mode

### Sandbox Details
- In sandbox mode (`APPSPRO_ENV=sandbox`), BDApps uses a mock carrier.
- No real mobile charges occur.
- No real SMS is delivered.
- The verification OTP is always **`000000`**.

### Running Backend Tests
Execute the comprehensive automated test suite:
```bash
cd server
node test/subscription.test.js
```
Validates:
- Valid HMAC-SHA256 signature acceptance (200).
- Body hash mismatch rejection (401).
- Stale/expired timestamp rejection (401).
- Invalid HMAC signature rejection (401).
- Event idempotency (duplicate event ID ignored).
- Lifecycle events (`created`, `cancelled`, `reactivated`).
- Premium endpoint gating (a test endpoint: 403 without subscription, 200 with subscription).
- Inbound SMS & USSD ingestion.

---

## 8. AppsPro Dashboard Configuration Checklist

1. **Webhook URL**:
   Set in the AppsPro Dashboard under **Webhooks**:
   `https://<YOUR_DOMAIN>/webhooks/appspro`
2. **Subscribed Events**:
   - `subscriber.created`
   - `subscriber.reactivated`
   - `subscriber.cancelled`
   - `subscriber.<status>`
   - `sms.received`
   - `ussd.received`
3. **Rotating Credentials**:
   - Generate a new Secret Key in AppsPro Dashboard.
   - Update `APPSPRO_SECRET_KEY` (and `APPSPRO_WEBHOOK_SECRET` if separate) in server environment.
   - Restart the server: `npm start`.
   - Never commit keys to source control.
