# Family sharing: build plan

Goal: a family member, on **their own phone**, can see whether the patient took their
medicines today, and gets a notification when a dose is missed.

## Status

- **Phase 1 (cloud backup): done.** Firestore lives in `asia-south1` (Mumbai). Rules are
  deployed.
- **Phase 2: built as revised below.** It also includes the caregiver's "Send reminder"
  (push).
- **Phase 3 (automatic missed-dose alerts to the caregiver): not started.**

## Revision: one account can be patient and caregiver

There are no exclusive roles. Every user gets their own medicine reminders, and any user can
also look after other people. Someone can be looked after by their son and, at the same
time, look after their own wife. So `kCaregiverRoleEnabled` stays off: the old separate
"Caregiver" sign-up role is replaced by the Family tab, which has two sections.

- **My family:** people who can see *my* medicines. Invite them, approve them, remove them.
- **People I look after:** a live view of each person's day, plus "Send reminder".

### Linking without the server (Firestore rules only)
1. **Invite.** The patient taps "Invite a family member". This turns on their cloud backup,
   with consent, because the caregiver reads from it. The app creates `invites/{code}`
   holding `{patientUid, patientName, expiresAt (+48h)}`. The code is 8 characters from a
   31-letter alphabet with no 0/O or 1/I, about 850 billion combinations. Anyone signed in
   may `get` an invite by its exact code, but nobody can list invites, so codes can't be
   found by browsing.
2. **Join.** The caregiver enters the code. The app writes
   `users/{patientUid}/family/{caregiverUid}` holding
   `{status: 'pending', inviteCode, caregiverName}`. The rules allow this only if the invite
   names that patient and hasn't expired. The app also writes
   `users/{caregiverUid}/caring/{patientUid}` holding `{patientName}` in the caregiver's own
   space.
3. **Approve.** The patient sees the request and approves it, which sets
   `status: 'active'`. Only the patient can make that change.
4. **Read.** Rules let a caregiver whose family entry is `active` **read** the patient's
   `medicines` and `doseLogs`. Nothing can be written there except by the patient.
5. **Remove.** Either side deletes the family entry. Access stops on the next read.

### Send reminder (caregiver to patient)
- The caregiver's app writes `users/{patientUid}/nudges/{id}`; only active family may
  create these. The patient's app shows unread reminders as a notification whenever it is
  running or next opened.
- The app also calls the server, `POST /family/remind`. The server checks the link and sends
  a **push notification** (FCM) to the patient's devices, which are registered under
  `users/{uid}/devices/{token}`. This needs the server to run with this Firebase project's
  service account.

The work is three phases. Each phase ships on its own and is useful by itself.

| Phase | What the user gets | Rough size |
|---|---|---|
| 1. Cloud sync | Medicines and history survive a new phone, a reinstall or a reset | 1 to 1.5 weeks |
| 2. Linking and family view | A family member links once and sees the patient's day live | 1.5 to 2 weeks |
| 3. Missed-dose alerts | The family member's phone notifies them when a dose is missed | 1 to 1.5 weeks |

Sizes assume one developer and include tests and two-phone testing. Add about a week for Play
Store review and privacy paperwork.

---

## Decisions needed before starting

1. **Push only, or SMS too?** Push (Firebase Cloud Messaging) is free. SMS through
   BDApps/AppsPro costs money per message, but it reaches family members who don't install the
   app. Recommendation: **push first**, SMS later as an option.
2. **Can family members only watch, or also edit medicines?** Recommendation: **watch only**
   at first. Editing someone else's medicines needs an audit trail and conflict handling.
3. **Who pays?** Is Family part of the existing daily subscription? Does the family member
   need their own subscription to use the app? Recommendation: the **patient's** subscription
   covers family members, and family members don't pay.
4. **Where does the missed-dose check run?** (Phase 3.) Render's free instance sleeps, so
   choose one:
   - **Firebase scheduled Cloud Function.** Needs the Blaze (pay-as-you-go) plan; cost is tiny
     at this scale.
   - **A paid Render instance plus a cron job.**
   Recommendation: **Cloud Function**.
5. **How many family members per patient?** Recommendation: up to **3**.

---

## Phase 1: Cloud sync of the patient's own data

The phone stays the main copy and must keep working offline. The cloud is a synced backup
that phases 2 and 3 can read.

### Data model (Firestore)

```
users/{uid}                      profile: name, age, phone, conditions, allergies, language
users/{uid}/medicines/{medId}    Medicine fields + updatedAt + deleted (soft delete)
users/{uid}/doseLogs/{logId}     DoseLog fields + scheduledDate + updatedAt
```

**Required model change:** `DoseLog` has `scheduledTime` ("08:00 AM") but no **date**.
- Add `scheduledDate` ("2026-11-18"), the date the dose was for, not when it was logged.
- Fill it in for old logs from `actualTime` when migrating.
- Phase 3 depends on it, and it also fixes "which day was this missed dose?" on the phone.

### App work
- **Package:** add `cloud_firestore`. Turn on Firestore's offline persistence. Hive stays the
  store the screens read from.
- **New `SyncService`:**
  - **Push:** every write in `MedicinesNotifier` (`addMedicine`, `updateMedicine`,
    `deleteMedicine`) and in `DoseLogsNotifier` (`addLog`, `recordMissedDoses`) also writes to
    Firestore. While offline, writes are queued and sent later.
  - **Pull:** on sign-in, and on a new phone, download the user's medicines and logs into Hive.
  - **Conflicts:** last write wins, using `updatedAt`. Deletes are soft (`deleted: true`), so
    they sync too.
- **Settings:** a line saying "Your medicines are backed up to your account" and when the last
  sync happened.
- **Account deletion** (`delete_account_tile.dart`) must also delete `users/{uid}` and
  everything under it. Do it server-side with the Admin SDK, inside the existing
  `DELETE /subscription/account` call.

### Security rules (first version)
```
match /users/{uid}/{document=**} {
  allow read, write: if request.auth.uid == uid;
}
```

### Done when
- Add a medicine on phone A, sign in on phone B, and it's there with its history.
- Airplane mode: take, skip and add work normally, then sync when back online.
- Deleting the account removes the Firestore data. Check in the Firebase console.
- Tests: SyncService with a fake Firestore; migration that adds `scheduledDate`.

---

## Phase 2: Linking and the family view

### How linking works
1. **Patient:** Settings → "Share with family" → **Create invite**. This makes a 6-digit code
   valid for 24 hours, with a "Send by SMS" button that opens their own SMS app (as today).
2. **Family member** (installs the app and signs in): chooses **"I help someone"** → enters
   the code.
3. **Patient confirms** on their phone: "Rahim wants to see your medicines. Allow?"
   Linking never happens without the patient's yes.
4. **Patient can see and remove** family members at any time. Removing takes effect
   immediately.

### Data model
```
invites/{code}                   patientUid, createdAt, expiresAt, usedBy (one use only)
users/{patientUid}/family/{familyUid}   name, relationship, status: pending|active, addedAt
users/{familyUid}/caring/{patientUid}   patient name (for the family member's list)
```
- Redeeming a code runs on the server through a new authenticated endpoint,
  `POST /family/redeem`. The app never reads `invites` directly, so codes can't be guessed or
  listed.
- Rate-limit code attempts per user (the server already uses `express-rate-limit`).

### Security rules (added)
```
match /users/{patientUid}/{col}/{doc} {
  allow read: if request.auth.uid == patientUid
    || (col in ['medicines', 'doseLogs'] &&
        get(/databases/$(database)/documents/users/$(patientUid)/family/$(request.auth.uid)).data.status == 'active');
}
```
A family member can **read** the patient's medicines and dose logs and nothing else: not the
profile notes or allergies unless the patient chooses to share them. They can never write.

### App work
- **Turn the Caregiver role back on:** set `kCaregiverRoleEnabled = true` and rename it
  **"I help someone"** / **"আমি দেখাশোনা করি"**.
- **Caregiver dashboard:** reads the patient's data live with Firestore streams instead of
  this phone's Hive data:
  - today's doses: taken, missed, upcoming
  - the last 7 days of adherence
  - "last updated" time, so a stale view is visible
  - a list of patients when the family member helps more than one
- **Patient's Family tab:** shows the patient's own sharing instead: who can see, pending
  requests, remove buttons, and "Create invite".
- **Remove the old "on THIS phone only" warning** once the live view exists, and update the
  privacy screen text.

### Done when
- Two phones: invite, redeem, confirm, and the family phone shows today's doses. A dose taken
  on the patient's phone appears on the family phone within seconds.
- After removal, the family phone loses access straight away (rules deny the read).
- Expired, reused and wrong codes are refused. Brute-forcing is rate-limited.
- Tests: redeem endpoint (server); rules tests with the Firebase emulator.

---

## Phase 3: Missed-dose alerts to the family

The patient's phone can't be trusted to report a miss: it may be off, out of battery, or the
app may have been closed. The check therefore runs on the server, from the synced data.

### How it works
1. **The check:** a scheduled job (see decision 4) runs **every 15 minutes**. For each patient
   with active family members:
   - work out the doses due today, from `medicines` (times, start and end dates, paused status;
     the same rules as `lib/core/utils/schedule_utils.dart`)
   - find the doses more than **1 hour** past their time with no taken or skipped log for
     today's `scheduledDate`
   - **check each dose once only:** record it in `users/{uid}/alertsSent/{date_medId_time}`.
2. **Notify** each active family member:
   - push through FCM: "Ammu missed Napa 500mg (8:00 AM)"
   - optional SMS, if chosen in decision 1.
3. **Respect the user:**
   - a family member can mute alerts per patient
   - no alerts between 11 PM and 7 AM unless the dose time itself was in that window; those
     wait and arrive as a 7 AM summary
4. **Optional daily summary:** at 9 PM, "Today: 5 of 6 doses taken".

### App work
- **Package:** add `firebase_messaging`. Save each device's push token under
  `users/{uid}/devices/{token}`, and remove it on sign-out and account deletion.
- **Notification channel:** a separate one ("Family alerts"), so it never mixes with the
  patient's own medicine alarms.
- **Tapping an alert** opens the caregiver dashboard for that patient.

### Shared schedule logic
The server must decide "due" and "missed" exactly as the app does. Port `schedule_utils.dart`
and `time_utils.dart` to JavaScript. Run the **same test cases** on both sides so they can't
drift (copy `test/schedule_logic_test.dart` cases into a server test).

### Done when
- With the patient's phone **switched off**, a missed 8:00 AM dose alerts the family phone by
  about 9:15 AM.
- Taken or skipped doses never alert. Each missed dose alerts once only.
- Muting, quiet hours and removal all stop alerts.
- Tests: missed-dose job with fixed clocks; de-duplication; quiet hours.

---

## Privacy and Play Store (needed before Phase 2 ships)

- **Consent screen** before the first cloud backup: what is stored, where, who can see it, and
  how to delete it.
- **Privacy policy** (in-app `privacy_screen.dart` and the public page): health data stored in
  Firebase (Google Cloud), shared only with family members the patient approves.
- **Play Console Data safety form:** health info and contacts are collected, encrypted in
  transit, and deletable. Also re-check the health-app declaration.
- **Account deletion** (already in the app) must delete Firestore data, family links in both
  directions, invites and device tokens. Extend `DELETE /subscription/account`, or add
  `DELETE /account`, and add tests.
- **Web deletion link** for Play: a simple page where people can request deletion without the
  app.

## Risks

| Risk | Mitigation |
|---|---|
| App and server disagree on what "missed" means | Shared test cases (Phase 3) |
| Phone clock or time-zone differences | Store `scheduledDate` plus the patient's time zone (Asia/Dhaka), and compute on the server in that zone |
| A family member sees data after being removed | Firestore rules re-check `status` on every read; remove the link from both directions on the server |
| Free Render instance sleeps, so alerts are late | Use a Firebase scheduled function, or a paid instance (decision 4) |
| Firestore cost | Small at this scale; set a budget alert in Google Cloud |
| Old app versions without `scheduledDate` | Server ignores logs without it; force-update prompt once Phase 3 ships |

## Order of work (checklist)

**Phase 1**
- [ ] Add `scheduledDate` to `DoseLog`, with a migration and tests
- [ ] Add `cloud_firestore`; build SyncService (push, pull, offline queue)
- [ ] Firestore rules (owner only) and emulator tests
- [ ] Account deletion also deletes Firestore data
- [ ] Two-phone test: sign in on a new phone and see the same data

**Phase 2**
- [ ] Server: `POST /family/invite`, `POST /family/redeem`, `DELETE /family/{uid}`, with
      rate limits and tests
- [ ] Rules: family read access, emulator tests
- [ ] Patient's sharing screen (Family tab)
- [ ] Re-enable the Caregiver role as "I help someone"; live dashboard
- [ ] Consent screen and privacy text

**Phase 3**
- [ ] Decide where the job runs (decision 4) and set it up
- [ ] Port the schedule logic to JS with shared test cases
- [ ] Missed-dose job, de-duplication and quiet hours
- [ ] `firebase_messaging`, device tokens, "Family alerts" channel
- [ ] Phone-off test: alert arrives on the family phone
