# OsudSheba

Medicine reminders for older adults in Bangladesh and the family members who help them.
Bangla and English. Flutter app (Android first; iOS and web build from the same code) with a small
Node.js backend for carrier-billing subscriptions (AppsPro / BDApps) and AI prescription reading.

## What the app does

- Loud, high-priority alarm notifications at each dose time, grouped by time ("3 medicines at
  8:00 AM"). They ring on the exact minute when the user allows "Alarms & reminders" for the app,
  otherwise up to a few minutes late. (No full-screen takeover: that permission is reserved by
  Google Play for alarm-clock and calling apps.)
- "I took it" / "Remind me in 10 minutes" on the alarm, read-aloud in Bangla or English.
- Doses not recorded within an hour are marked **missed**. Earlier unrecorded doses can be
  recorded later from the home screen.
- Adherence history and a simple Family tab showing what was taken or missed **on this phone**.
- Optional: photograph a prescription; the AI suggestion must be checked and confirmed before saving.
- Settings → "Delete my account": cancels the carrier subscription first, then deletes the server
  record, the Firebase account and everything on the phone.

The separate "Caregiver" role is switched off at launch (`kCaregiverRoleEnabled` in
`lib/core/constants/app_features.dart`) because there is no syncing between phones yet.

What it does **not** do (and no screen claims otherwise): send SMS reminders, alert family members on
another phone, or call for help in an emergency.

## Project layout

```
lib/
  app/            app shell, router, theme
  core/
    services/     notifications (alarms), storage (Hive), auth (Firebase), subscription, TTS, AI
    utils/        time_utils.dart (time parsing), schedule_utils.dart (course dates, missed doses)
  features/       screens by feature
  shared/widgets/ accessible buttons, confirm dialog, cards
server/           Express backend (subscriptions, webhook, prescription analysis)
test/             Flutter unit/widget tests
```

## Run locally

```bash
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=BACKEND_BASE_URL=http://10.0.2.2:3000   # Android emulator + local server
```

`lib/firebase_options.dart` and `android/app/google-services.json` are git-ignored; generate them with
`flutterfire configure`.

Server:

```bash
cd server
cp .env.example .env      # fill in real values; never commit .env
npm ci
npm test                  # offline suites, isolated temp data store
npm start
```

## Release checklist (Android)

1. **Signing:** create an upload keystore and `android/key.properties` (git-ignored):
   `storePassword=…`, `keyPassword=…`, `keyAlias=upload`, `storeFile=/abs/path/upload-keystore.jks`.
   Without it the release build is debug-signed and Google Play will reject it.
2. **Backend URL:** release builds default to `https://osudsheba.onrender.com`; override with
   `--dart-define=BACKEND_BASE_URL=…` if needed.
3. **Server environment (Render):** `NODE_ENV=production`, real `APPSPRO_*` keys,
   `APPSPRO_ALLOW_SIMULATION` unset, `ALLOW_MOCK_AUTH` unset, `ALLOWED_ORIGINS` set, and
   `GOOGLE_APPLICATION_CREDENTIALS`/`FIREBASE_CONFIG` set so subscriptions are stored in Firestore
   (the JSON-file fallback is lost whenever the Render instance restarts).
4. `flutter build appbundle --release`
5. On a real phone: Settings → Reminders & alarms → "Ring a test alarm in 1 minute", with the screen
   locked, battery saver on, and after a reboot.
6. Deploy the server before the app: in-app account deletion calls `DELETE /subscription/account`.
7. Play Console: privacy policy URL, Data safety form (account email/phone, subscription phone number,
   prescription photos sent to an AI service), health-app declaration, and an account-deletion
   web link (Play also requires a way to request deletion without the app). The app no longer
   declares `USE_EXACT_ALARM` or `USE_FULL_SCREEN_INTENT`, so no declarations are needed for them.
