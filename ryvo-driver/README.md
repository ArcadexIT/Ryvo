# Ryvo Driver App

Flutter app for drivers on the Ryvo ride, bid, and parcel platform. A driver goes online, accepts ride, bid, and parcel jobs, navigates to the rider, and tracks earnings and payouts. The app includes identity and vehicle verification, subscriptions, and chat.

Part of the Ryvo package. The other parts are `ryvo-customer` (Flutter), and `ryvo-admin` (NestJS API and Next.js admin panel).

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

- Replace every `xxxxxxxx` placeholder (Maps key in `AndroidManifest.xml` and `GMSApiKey` in `ios/Runner/Info.plist`).
- Run `flutterfire configure` to create your own Firebase files.
- Use an Android application id and iOS bundle id different from the customer app.
- In Xcode, choose your own Apple Team under Signing & Capabilities.

## Stack

Flutter, Riverpod, GoRouter, Dio, Google Maps, fl_chart, Firebase Cloud Messaging, Stripe.
