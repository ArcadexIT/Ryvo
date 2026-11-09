# Ryvo Customer — TestFlight

## App identity (copy into App Store Connect)

| Field | Value |
|-------|--------|
| App name | Ryvo |
| Fallback name if “Ryvo” is taken | Ryvo Rides |
| Subtitle | Everyday rides, on demand |
| Bundle ID | `com.ryvo.customer` |
| SKU | `ryvo-customer-ios` |
| Primary language | English (U.K.) |
| Version | `1.0.0` |
| Build | `5` |
| Apple Team | `PKL9VLU62B` (Ryvo Ltd) |
| Minimum iOS | 15.6 |
| Devices | iPhone and iPad |
| Category | Travel |
| Secondary category | Navigation |
| Copyright | 2026 Ryvo Ltd |
| Content rights | Does not contain third-party content |
| Price | Free |
| Privacy policy | https://ryvo.arcadexit.com/privacy-policy/ |
| Support URL | https://ryvo.arcadexit.com |
| Marketing URL | https://ryvo.arcadexit.com |
| Support email | enquiries@ryvo.arcadexit.com |
| Company | Ryvo Ltd, 128 City Road, London, United Kingdom, EC1V 2NX |

Home-screen name is **Ryvo** (`CFBundleDisplayName`). The internal bundle name is also **Ryvo**.

## Signing and capabilities

Enable these on the App ID `com.ryvo.customer` in the Apple Developer account before the first archive:

- Push Notifications
- Apple Pay, merchant ID `merchant.ryvo.arcadexit.com`
- Background Modes: Remote notifications

Signing in the Xcode project is Automatic, team `PKL9VLU62B`.

| Build | Push entitlement |
|-------|------------------|
| Debug (device runs) | `development` in `ios/Runner/Runner.entitlements` |
| Release and Profile (TestFlight) | `production` in `ios/Runner/RunnerRelease.entitlements` |

Firebase iOS app: project `ryvo-7b28a`, bundle `com.ryvo.customer`. Upload the APNs key to that Firebase app or TestFlight pushes stay silent.

URL scheme used for Stripe return: `ryvo`.

## Export compliance

The app uses HTTPS, Stripe, and Firebase only. `ITSAppUsesNonExemptEncryption` is `false`.

In App Store Connect, for every build:

- Uses non-exempt encryption: **No**

## App Privacy answers

Data is linked to the user and used for app functionality. Tracking is off.

| Data | Collected |
|------|-----------|
| Precise location | Yes. Pickup, nearby drivers, trip follow |
| Name, email, phone | Yes. Account |
| Photos | Yes. Optional vehicle photo |
| Payment info | Yes. Cards and wallet through Stripe. Ryvo does not store the card number |
| User ID | Yes |
| Diagnostics / advertising | No |

## Age rating

No unrestricted web, gambling, or mature themes. Declare in-app messages between the customer and the driver if the questionnaire asks about user-generated content. Expect **4+** unless chat raises it.

## Archive and upload

Build 4 is already on App Store Connect. The next upload is build 5. Each later upload needs a higher number after `+` in `pubspec.yaml`.

```bash
cd ryvo-customer
flutter build ipa --export-options-plist=ios/ExportOptions.plist
```

The IPA is written under `build/ios/ipa/`. Upload it with the Transporter app, or in Xcode via Product → Archive → Distribute App → App Store Connect.

## TestFlight test information

- Beta App Description: Ryvo lets a customer book a ride or send a parcel, watch the driver on the map, and pay in the app.
- Feedback email: enquiries@ryvo.arcadexit.com
- Sign-in required: Yes. Phone number and one-time code.
- Put a demo phone number that can receive the code in Test Information → Sign-In Information before external testing.

Internal testers (App Store Connect users on the Ryvo Ltd team) can install as soon as processing finishes. External testers need Beta App Review and the privacy policy URL.

## Screenshots

Not required for an internal TestFlight install. Required before the App Store release, and the binary is universal so iPad shots are required too.

iPhone 6.7" (1290 × 2796): home map, vehicle choice, searching, live trip, payment.

iPad 13" (2064 × 2752): the same five screens.

## Still done in App Store Connect, not in the repo

- Create the app record with the bundle ID above
- Confirm the Apple Pay merchant and Push capability on that App ID
- Upload the APNs key to Firebase
- Upload the IPA
- Add the demo sign-in phone for external review
