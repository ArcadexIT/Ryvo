# Ryvo Customer — App Store Prepare Checklist

## App identity

| Field | Value |
|-------|--------|
| Display name | Ryvo Customer |
| Bundle ID | `com.ryvo.customer` |
| Version | `1.0.0` |
| Build | `1` (bump `+N` in `pubspec.yaml` for each upload) |
| Team | `PKL9VLU62B` (Ryvo Ltd — Apple Developer Program) |
| Minimum iOS | 14.0 |
| Privacy policy | https://ryvo.arcadexit.com/privacy-policy/ |
| Contact | enquiries@ryvo.arcadexit.com |

## Already prepared in the project

- Photo library usage description in `ios/Runner/Info.plist`
- Location when-in-use usage description (Always string removed — matches current when-in-use geolocation)
- App icons including 1024×1024 marketing icon
- Podfile platform iOS 14.0
- Cleartext traffic disabled on Android for production HTTPS

## Before Archive in Xcode

1. Open `ios/Runner.xcworkspace` (not `.xcodeproj`)
2. Select **Runner** → Signing & Capabilities → Team **`PKL9VLU62B` (Ryvo Ltd)**, Automatic signing
3. Do **not** use a free personal Apple ID team — use the **Ryvo Ltd** org membership
4. Confirm **Push Notifications** capability for App ID `com.ryvo.customer`
5. Confirm Release archive shows `aps-environment` = **production**
6. Add APNs key/certificate to Firebase for this iOS app
7. Restrict Google Maps iOS API key to bundle ID `com.ryvo.customer`
8. Answer export compliance in App Store Connect (standard HTTPS / Stripe)

### Google Maps on iOS (blank map / blue dot only)

If the map shows your location but no roads or tiles:

1. Open [Google Cloud Console](https://console.cloud.google.com/) → **APIs & Services** → **Library**
2. Enable **Maps SDK for iOS** (separate from Android)
3. Go to **Credentials** → your Maps API key (`AIzaSyD-nDby…`)
4. Under **Application restrictions**, add **iOS apps** with bundle ID `com.ryvo.customer`
   - If the key is restricted to **Android apps only**, iOS tiles will not load
5. Ensure **billing** is enabled on the Google Cloud project

The key is set in `ios/Runner/Info.plist` (`GMSApiKey`) and loaded in `AppDelegate.swift`.

If Xcode shows a provisioning error:

1. Xcode → **Runner** → Signing & Capabilities → set Team to **`PKL9VLU62B` (Ryvo Ltd)**
2. Confirm Bundle Identifier is **`com.ryvo.customer`**
3. **Product → Clean Build Folder**, then rebuild

## Archive & upload

```bash
cd ios
pod install
cd ..
flutter build ipa --release
# or: open ios/Runner.xcworkspace → Product → Archive → Distribute App
```

## Screenshots (App Store Connect)

iPhone (required):
- 6.7" display (e.g. 1290 × 2796) — recommended set

Suggested captures:
1. Home map / request
2. Provider assigned / searching
3. Live tracking
4. Payment
5. Bookings

## App Store listing copy

- Name: **Ryvo** (or **Ryvo Customer** if name conflict)
- Subtitle (≤30 chars): `Jump-start help, fast`
- Description: copy from `store/play/full-description.txt`
- Keywords (≤100 chars): `jump start,roadside,battery,breakdown,assistance,car help,towing`
- Support URL: https://ryvo.arcadexit.com/privacy-policy/
- Marketing URL (optional): https://ryvo.arcadexit.com
- Privacy Policy URL: https://ryvo.arcadexit.com/privacy-policy/

## Review notes (optional)

This app lets drivers request on-demand emergency car jump-start assistance. Users create an account, share location while using the app, request a verified provider, track arrival live, chat if needed, and pay with Stripe. Test account: provide credentials in App Store Connect if required for review.

## Not done in this pass

- IPA upload to App Store Connect
- Production APNs verification in Firebase
- App Store Connect metadata entry
