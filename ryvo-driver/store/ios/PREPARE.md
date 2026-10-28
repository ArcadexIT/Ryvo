# Ryvo Driver — App Store Prepare Checklist

## App identity

| Field | Value |
|-------|--------|
| Display name | Ryvo Driver |
| Bundle ID | `com.ryvo.driver` |
| Version | `1.0.0` |
| Build | `1` (bump `+N` in `pubspec.yaml` for each upload) |
| Team | `QH8B96AQPH` |
| Minimum iOS | 14.0 |
| Privacy policy | https://ryvo.arcadexit.com/privacy-policy/ |
| Contact | enquiries@ryvo.arcadexit.com |

## Already prepared in the project

- Camera & photo library usage descriptions in `ios/Runner/Info.plist`
- Location when-in-use usage description (Always string removed — matches current when-in-use geolocation)
- App icons including 1024×1024 marketing icon
- Firebase `GoogleService-Info.plist` bundle ID match
- Podfile platform set to iOS 14.0; run `pod install` after clone

## Before Archive in Xcode

1. Open `ios/Runner.xcworkspace` (not `.xcodeproj`)
2. Select **Runner** → Signing & Capabilities → Team `QH8B96AQPH`, Automatic signing
3. Confirm **Push Notifications** capability is enabled for App ID `com.ryvo.driver` in Apple Developer
4. Confirm Release archive shows `aps-environment` = **production** (not development)
5. Add APNs key/certificate to Firebase for this iOS app
6. Restrict Google Maps iOS API key to bundle ID `com.ryvo.driver`
7. Answer export compliance in App Store Connect (standard HTTPS encryption)

## Archive & upload

```bash
cd ios
pod install
cd ..
flutter build ipa --release
# or: open ios/Runner.xcworkspace → Product → Archive → Distribute App
```

Upload via Xcode Organizer or Transporter to App Store Connect.

## Screenshots (App Store Connect)

iPhone (required for submission):
- 6.7" display (e.g. 1290 × 2796) — recommended set
- Also prepare 6.5" / 5.5" if prompted by Connect

Suggested captures (same as Play):
1. Home map online
2. Incoming job accept
3. Navigation / active job
4. Earnings
5. Profile / verification

## App Store listing copy (reuse Play text)

- Subtitle (≤30 chars): `Jump-start jobs & earn`
- Description: copy from `store/play/full-description.txt`
- Keywords (≤100 chars, comma-separated): `jump start,roadside,provider,earn,towing,battery,assistance`
- Support URL: https://ryvo.arcadexit.com/privacy-policy/ (or a dedicated support page if you add one)
- Marketing URL (optional): https://ryvo.arcadexit.com
- Privacy Policy URL: https://ryvo.arcadexit.com/privacy-policy/

## Review notes (optional text for App Review)

This app is for registered roadside assistance providers, not end customers. Providers create an account, complete KYC document upload, go online to receive nearby jump-start job requests, navigate to customers, complete jobs, and withdraw earnings. Location is used while the app is in use for map position and job matching. Test account: provide credentials in App Store Connect if required for review.

## Not done in this pass

- IPA upload to App Store Connect (needs your Apple ID session)
- Production APNs verification in Firebase
- App Store Connect metadata entry
