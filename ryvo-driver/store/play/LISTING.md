# Ryvo Driver — Google Play listing pack

Version to upload: **1.0.0** (versionCode **7**). Package **com.arcadexit.ryvo.driver**.

`com.ryvo.driver` stays the Kotlin namespace and the iOS bundle id. The Play application id is `com.arcadexit.ryvo.driver`. Add this package in Firebase project `ryvo-7b28a` and on the Maps API key before shipping, then replace `android/app/google-services.json` with the file Firebase downloads for that app.

The old “Jomp” / jump-start graphics and description do not match this app. Use the files in this folder.

## Still required before you can press Publish

1. Use the shared upload keystore at `~/keystores/ryvo-upload.jks` (alias `ryvo_upload`). `android/key.properties` is gitignored and already points at it. Fingerprints are in `UPLOAD_CERT_SHA.txt`. Register those on the Firebase and Maps apps for this package, not the fingerprints from the project this repo was cloned from.
2. On https://ryvo.arcadexit.com/privacy-policy/ remove the sentence that calls the policy a product placeholder, and add a “Delete your account” section (steps are in the chat reply).
3. Capture at least 2 phone screenshots (1080×1920 PNG, no transparency).
4. Create a verified UK driver test account and enter it under App access.
5. Build and upload the bundle:

```bash
flutter build appbundle --release
```

The file is `build/app/outputs/bundle/release/app-release.aab`.

## Assets in this folder

| File | Spec |
|------|------|
| `short-description.txt` | 55 characters |
| `full-description.txt` | Store description |
| `icon-512.png` | 512×512 PNG |
| `feature-graphic.png` | 1024×500 PNG, no alpha |
| `UPLOAD_CERT_SHA.txt` | Shared upload certificate |

Screenshots are not in this folder. Capture: home map online, incoming ride, trip navigation, earnings, profile.
