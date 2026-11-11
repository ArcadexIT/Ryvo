# Ryvo customer — Google Play console pack

Version in `pubspec.yaml`: **1.0.0** (versionCode **5**). Package **com.arcadexit.ryvo.customer**.

`com.ryvo.customer` is already registered on Google Play, so the Android application id is `com.arcadexit.ryvo.customer`. The iOS bundle id stays `com.ryvo.customer`. Add this new package in Firebase project `ryvo-7b28a` and on the Maps API key before shipping. The Kotlin namespace is still `com.ryvo.customer`.

## Create the app

| Field | Value |
| --- | --- |
| App name | Ryvo |
| Fallback if “Ryvo” is taken | Ryvo Rides |
| Default language | English (United Kingdom) – en-GB |
| App or game | App |
| Free or paid | Free |
| Category | Maps & navigation |
| Tags | Taxi & ride-hailing, if offered |
| Developer | Ryvo Ltd |
| Email | enquiries@ryvo.arcadexit.com |
| Phone | Add the company phone you want shown on the listing |
| Website | https://ryvo.arcadexit.com |
| Privacy policy | https://ryvo.arcadexit.com/privacy-policy/ |

The public privacy policy still says it is a product placeholder. Replace that line and have it reviewed before you submit. Play rejects an unfinished policy.

## Store listing

Paste `short-description.txt` (71 characters, limit 80) and `full-description.txt`.

| Asset | File | Spec |
| --- | --- | --- |
| App icon | `store/play/icon-512.png` | 512×512, 32-bit PNG |
| Feature graphic | `store/play/feature-graphic.png` | 1024×500, no transparency |
| Phone screenshots | Not in the repo yet | At least 2, JPEG or 24-bit PNG, 1080×1920 recommended |

Capture these on a phone, in order: home map, vehicle choice, searching, live trip, payment. Tablet screenshots are required only if you leave tablets enabled. For a phone-only launch, open Reach and devices → Device catalog and exclude tablets, or upload 7-inch and 10-inch shots of the same five screens.

## App access (review login)

Sign-in is required. In Play Console → App content → App access, choose “All or some functionality is restricted” and add:

- A UK phone number that receives the one-time code, or a number whose code is fixed in the backend
- The password, if the review account uses one
- Steps: open Ryvo → enter the phone number → enter the code → the map is the home screen

Without this, review stops on the login screen.

## Ads

No. The app does not show ads and the advertising-ID permission is stripped from the manifest. Answer “No” to “Does your app use advertising ID?”.

## Target audience and content

- Target age: 18 and over
- Not designed for children. Do not opt into Designed for Families
- Appeal to children: No
- News app: No
- COVID-19 contact tracing or status: No
- Government app: No
- Health app: No

Content rating (IARC), “All other app types”:

| Question | Answer |
| --- | --- |
| Violence, sexual content, language, controlled substances, crude humour, gambling | No |
| Users can interact or exchange content | Yes. Trip chat with the assigned driver. Report is in the chat screen and opens a support ticket |
| Shares the user’s current physical location with other users | Yes. Pickup, drop-off, and live position go to the assigned driver |
| Purchases digital goods | No. Rides and parcels are real-world services. Stripe is allowed. Do not enable Play Billing |
| Unrestricted web browsing | No |
| Shares precise location | Yes |

Expected rating: Teen or 18+, because of user-to-user chat and location sharing. Accept the questionnaire result.

## Data safety

Data is encrypted in transit (HTTPS). The app does not sell data. Data is not used for advertising or tracking.

| Data | Collected | Shared | Purpose | Required |
| --- | --- | --- | --- | --- |
| Precise location | Yes | Yes, with the assigned driver | App functionality | Yes, to request a trip |
| Name | Yes | Yes, first name with the driver | Account, app functionality | Yes |
| Email address | Yes | No | Account | Yes at registration |
| Phone number | Yes | Yes, with the driver for the trip | Account, app functionality | Yes |
| User IDs | Yes | No | Account, app functionality | Yes |
| Photos | Yes, optional vehicle photo | No | App functionality | No |
| Financial info / purchase history | Yes. Trip payments and invoices. Card numbers stay with Stripe | Yes, with Stripe to take payment | App functionality | Yes, to pay |
| Messages | Yes. Trip chat and support tickets | Yes, with the driver and support | App functionality | No |
| Device or other IDs | Yes. Firebase push token | Yes, with Firebase to deliver notifications | App functionality | No |

Not collected: contacts from the phone, SMS, calendar, health, files, web browsing, crash logs, diagnostics, advertising ID, installed apps.

Account deletion in the Data safety form:

- Users can request account deletion: Yes
- Web URL: publish `store/play/delete-account.html` at `https://ryvo.arcadexit.com/delete-account` and paste that URL. The path 404s today, so do not submit until it loads
- In the app: Profile → Delete account. That files a support ticket. Someone on the Ryvo side has to delete the account. A ticket alone does not remove the user

What deletion removes: profile, saved places, vehicles, messages, notification token. What may be kept: trip and payment records required for tax, fraud, and disputes. Say that in the form.

## Financial features

The Play “financial features” form is about loans, banking, crypto, and similar products. Answer **No**. The wallet only pays for Ryvo trips. It is not a bank account.

Payments for rides and parcels are real-world services, so Stripe (and cash, where enabled) is allowed. Do not add Google Play Billing.

## Location and permissions declaration

| Permission | Declare |
| --- | --- |
| Approximate and precise location | Yes. Foreground only, while the rider is using the app, to set pickup and follow the trip |
| Background location | No |
| Photos and video (broad library access) | No. An optional vehicle photo uses the system photo picker |
| Notifications | Trip updates. Not a special Play declaration |
| Advertising ID | No |
| Foreground service | The geolocator plugin binds a location service so in-app updates work. The app does not turn on background mode and does not show a persistent location notification. If Console still asks, say location is used only while the app is open |

## Signing and the release file

Customer and driver share one new upload key. The certificate from the project this repo was cloned from is not used.

| | |
| --- | --- |
| Alias | `ryvo_upload` |
| File | `~/keystores/ryvo-upload.jks` |
| Fingerprints | `store/play/UPLOAD_CERT_SHA.txt` |

`android/key.properties` is gitignored and points at that file. Then:

```bash
cd ryvo-customer
flutter build appbundle
```

The bundle is `build/app/outputs/bundle/release/app-release.aab`. Upload that. Choose Google Play App Signing and let Google hold the app signing key.

After the first upload, open Play Console → App signing and copy the **App signing key** SHA-1 and SHA-256. Add those, plus the upload SHA above, to:

- Google Cloud → the Maps key used in the Android manifest (`com.arcadexit.ryvo.customer`)
- Firebase project `ryvo-7b28a` → Android app `com.arcadexit.ryvo.customer`

Maps and push stay blank in the Play build until the app-signing SHA is registered. The upload SHA alone is not enough.

## Release notes for 1.0.0

First public release of Ryvo for riders. Book a ride or send a parcel, follow the driver, and pay in the app.

## Countries

Start with the countries where coverage is actually on (the app checks `/customer/coverage/check`). United Kingdom is the home market. Do not turn on the rest of the world until drivers are live there.

## Still outside the repo

1. Build the `.aab` and upload it to the new Play Console app whose package name is `com.arcadexit.ryvo.customer`
2. Publish `delete-account.html` at `https://ryvo.arcadexit.com/delete-account`
3. Remove the “product placeholder” line from the privacy policy
4. Confirm production app-config returns a live Stripe publishable key (`pk_live_…`). The app falls back to a test key if that fetch fails
5. Create the review phone number and put it in App access
6. Capture phone screenshots
7. Delete accounts when a “Delete my Ryvo account” ticket arrives
8. After upload, register the Play app-signing SHA on Maps and Firebase
