# RYVO install guide

This is the path a non-developer can follow. Video script outlines are at the end.

## 1. Server (one command)

On a fresh Ubuntu 24.04 VPS with Docker-capable access:

```bash
git clone <your-ryvo-repo>
cd Ryvo
bash ryvo-admin/docker/install.sh
```

The script installs Docker if needed, asks for domain, Stripe, Maps, and Twilio, writes env files, and starts Postgres, Redis, API, admin, and Caddy.

When it finishes:

- Open `https://your-domain`
- Sign in with the printed admin phone / `123456`
- Change the admin password
- Admin → Settings: confirm Maps, Stripe publishable key, currency, commission vs subscription

Firebase push: replace `ryvo-admin/apps/api/firebase-service-account.json` with a real service account JSON, then `bash ryvo-admin/docker/redeploy.sh`.

## 2. Flutter apps (store builds)

```bash
cp scripts/whitelabel.env.example scripts/whitelabel.env
# edit API_BASE_URL to https://your-domain/api/v1
bash scripts/configure-apps.sh
```

Run the printed `flutter build apk` / `flutter build ipa` commands. Change the Android application id and iOS bundle id before the first store listing.

## 3. WhatsApp booking

Full step-by-step (sandbox, webhook, Admin toggle, test chat, going live): [WHATSAPP.md](WHATSAPP.md).

1. In Twilio, enable WhatsApp (sandbox is enough to test).
2. Set `TWILIO_WHATSAPP_FROM` in `apps/api/.env.production`.
3. Webhook URL: `https://your-domain/api/v1/webhooks/whatsapp` (HTTP POST).
4. Admin → Settings → enable WhatsApp booking.
5. Optional: set `OPENAI_API_KEY` for natural-language understanding. Without it, riders reply Ride / Bid / Parcel then send addresses.

## 4. Stripe

- Secret key on the API env file
- Publishable key in Admin → Settings → Billing
- Webhook: `https://your-domain/api/v1/webhooks/stripe` with `payment_intent.succeeded` (jobs and driver subscriptions)

## Free installation runbook

See [FREE_INSTALL_RUNBOOK.md](FREE_INSTALL_RUNBOOK.md) if you are installing this for a buyer.

## Video scripts (record these)

1. **Server install (8 min):** clone repo → run `install.sh` → fill prompts → open admin → change password.
2. **Firebase + Maps (6 min):** create Firebase project, download service account, Maps JavaScript / SDK keys, paste into Settings.
3. **Store builds (10 min):** `configure-apps.sh`, Android package name, signing, Play Console; iOS bundle id, certificates, App Store Connect.
