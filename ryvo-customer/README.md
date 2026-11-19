# Ryvo Customer App

Flutter app for riders on the Ryvo ride, bid, and parcel platform. A rider can request a ride, send a bid to nearby drivers, or send a parcel. The app includes live tracking, chat, wallet, card and cash payment, invoices, and support.

Part of the Ryvo package. The other parts are `ryvo-driver` (Flutter), and `ryvo-admin` (NestJS API and Next.js admin panel).

## Documentation

Open `documentation/index.html` at the root of the package. It covers server install, Google Maps, Firebase, Stripe, signing, and store builds.

## Run

```bash
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=https://your-domain.com/api/v1 \
  --dart-define=WS_BASE_URL=https://your-domain.com \
  --dart-define=GOOGLE_MAPS_API_KEY=your-maps-key
```

From the package root, `bash scripts/configure-apps.sh` prints the full build commands from `scripts/whitelabel.env`.

## Before you ship

- Replace every `xxxxxxxx` placeholder (Maps key in `AndroidManifest.xml` and `ios/Runner/Info.plist`).
- Run `flutterfire configure` to create your own Firebase files.
- Change the Android application id and iOS bundle id.
- In Xcode, choose your own Apple Team under Signing & Capabilities.

## Stack

Flutter, Riverpod, GoRouter, Dio, Google Maps, Firebase Cloud Messaging, Stripe.
