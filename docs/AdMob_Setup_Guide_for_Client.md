# Proxi Mobile App — Google AdMob Setup Guide

**Document purpose:** Step-by-step instructions for your client to obtain the AdMob App IDs and Banner Ad Unit IDs required for the Proxi Flutter app (Android and iOS).

**Prepared for:** Proxi app integration  
**Date:** May 2026

---

## 1. Important: AdSense vs AdMob

| Product | Used for |
|---------|----------|
| **Google AdSense** | Websites and blogs |
| **Google AdMob** | Android and iOS mobile apps |

The Proxi app uses **Google AdMob** (via the official Flutter `google_mobile_ads` SDK). If the client already has AdSense, they can **link AdSense to AdMob** in the same Google account to simplify payments and reporting.

**Official links:**
- AdMob: https://admob.google.com  
- Link AdSense to AdMob: AdMob → **Payments** → follow prompts to connect AdSense  

---

## 2. What the development team needs (4 values)

These values are configured in the app and (optionally) on your backend admin panel.

| # | Name | Format example | Where it goes |
|---|------|----------------|---------------|
| 1 | **Android App ID** | `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` | Android app config |
| 2 | **iOS App ID** | `ca-app-pub-XXXXXXXXXXXXXXXX~ZZZZZZZZZZ` | iOS app config |
| 3 | **Android Banner Ad Unit ID** | `ca-app-pub-XXXXXXXXXXXXXXXX/AAAAAAAAAA` | App + backend `banner_android_unit_id` |
| 4 | **iOS Banner Ad Unit ID** | `ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB` | App + backend `banner_ios_unit_id` |

**Note:** App IDs contain a **tilde (`~`)**. Ad Unit IDs contain a **slash (`/`)**. Do not mix them up.

---

## 3. Test IDs currently in the project (development only)

While building and testing, the app uses **Google’s official sample IDs**. These show test ads only and must **not** be used in production or App Store / Play Store release builds.

| Item | Test value (do not use in production) |
|------|----------------------------------------|
| Android App ID | `ca-app-pub-3940256099942544~3347511713` |
| iOS App ID | `ca-app-pub-3940256099942544~1458002511` |
| Android Banner Unit | `ca-app-pub-3940256099942544/6300978111` |
| iOS Banner Unit | `ca-app-pub-3940256099942544/2934735716` |

Source: [Google AdMob test ads documentation](https://developers.google.com/admob/android/test-ads)

---

## 4. Prerequisites for the client

Before starting, the client should have:

1. A **Google account** (Gmail or Google Workspace).
2. **Google Play Console** access (Android) — app package name must match AdMob registration.
3. **Apple Developer Program** access (iOS) — bundle ID must match AdMob registration.
4. App store listing details (app name, category) for AdMob app review.
5. A **privacy policy URL** (required by AdMob and app stores).
6. Completed **AdMob payment profile** (tax and bank details) if they want to earn revenue.

---

## 5. Step-by-step: Create AdMob account

1. Go to **https://admob.google.com**
2. Sign in with the Google account that should own the app’s ad revenue.
3. Accept the AdMob terms and complete account setup.
4. If prompted, link an existing **AdSense** account (recommended for payouts).

---

## 6. Step-by-step: Register the Android app

1. In AdMob, open **Apps** → **Add app**.
2. Choose **No** if the app is not yet published on Google Play (you can link the store listing later).
3. Select platform: **Android**.
4. Enter the app name: **Proxi** (or the exact store name).
5. Enter the **Android package name** (must match the app exactly):  
   **`com.app.proxiapp`**
6. Save the app.

### Get the Android App ID

1. Open the registered **Android** app in AdMob.
2. Go to **App settings** (gear icon) or the app overview.
3. Copy the **App ID** — it looks like:  
   `ca-app-pub-1234567890123456~0987654321`

**Send this to the development team as: Android App ID**

---

## 7. Step-by-step: Register the iOS app

1. **Apps** → **Add app** again.
2. Choose **No** if not yet on the App Store (link later if needed).
3. Platform: **iOS**.
4. App name: **Proxi**.
5. Enter the **Bundle ID** (must match Xcode exactly):  
   **`com.app.proxiapp`**
6. Save.

### Get the iOS App ID

1. Open the **iOS** app in AdMob.
2. Copy the **App ID**:  
   `ca-app-pub-1234567890123456~0987654321`

**Send this to the development team as: iOS App ID**

---

## 8. Step-by-step: Create Banner ad units

The Proxi app shows a **small banner** at the bottom of screens for **Freemium** users only.

### Android banner

1. In AdMob, select the **Android** Proxi app.
2. **Ad units** → **Add ad unit**.
3. Select **Banner**.
4. Name suggestion: `Proxi Android Banner` or `Proxi Freemium Banner`.
5. Create and copy the **Ad unit ID**:  
   `ca-app-pub-1234567890123456/1234567890`

**Send as: Android Banner Ad Unit ID**

### iOS banner

1. Select the **iOS** Proxi app.
2. **Ad units** → **Add ad unit** → **Banner**.
3. Name suggestion: `Proxi iOS Banner`.
4. Copy the **Ad unit ID**.

**Send as: iOS Banner Ad Unit ID**

---

## 9. Information to send to the development team

Please fill in and email this checklist:

```
PROXI ADMOB — CLIENT PROVIDED VALUES
----------------------------------
Android package name:     com.app.proxiapp
iOS bundle ID:            com.app.proxiapp

Android App ID:           ca-app-pub-________________~________
iOS App ID:               ca-app-pub-________________~________

Android Banner Unit ID:   ca-app-pub-________________/________
iOS Banner Unit ID:       ca-app-pub-________________/________

AdMob account email:      _______________________________
Privacy policy URL:       _______________________________

Backend ads API (future):
  ads_enabled:            true / false (admin toggle)
```

---

## 10. Backend admin toggle (when API is ready)

The app will call:

`GET https://myproxi.app/index.php/api/v1/settings/ads`

Expected JSON (example):

```json
{
  "ads_enabled": true,
  "banner_android_unit_id": "ca-app-pub-XXXX/YYYY",
  "banner_ios_unit_id": "ca-app-pub-XXXX/ZZZZ"
}
```

- **`ads_enabled`**: `true` = show ads for eligible Freemium users; `false` = hide all ads app-wide without an app update.
- Paid plans (e.g. Elite) do not see ads unless testing in debug mode.

---

## 11. App store and policy requirements

The client should ensure:

1. **Privacy policy** mentions use of Google advertising (cookies/SDKs as applicable).
2. **Google Play** — declare ads in the app content questionnaire.
3. **Apple App Store** — App Privacy details include advertising if applicable.
4. **Families / children** — If the app is child-directed, AdMob has strict policies; declare correctly in AdMob.

---

## 12. Testing vs production

| Environment | Ad IDs | Who sees ads |
|-------------|--------|--------------|
| Development (test IDs) | Google sample IDs in project | Developers; test ads only |
| Production | Client’s real AdMob IDs | Freemium users when `ads_enabled` is true |

**Never** submit to the App Store or Play Store with Google’s test App IDs in production configuration.

---

## 13. Troubleshooting

| Issue | What to check |
|-------|----------------|
| No ads showing | `ads_enabled` on backend; user on Freemium plan; AdMob account approved |
| “Ad failed to load” | Wrong App ID in native config; ad unit not linked to correct app |
| Revenue not showing | Payment profile incomplete; allow 24–48 hours after first impressions |
| iOS ads blocked | `GADApplicationIdentifier` in Info.plist must match iOS App ID |

---

## 14. Support contacts

- AdMob Help Center: https://support.google.com/admob  
- Google AdMob policies: https://support.google.com/admob/answer/6128543  

---

*End of document*
