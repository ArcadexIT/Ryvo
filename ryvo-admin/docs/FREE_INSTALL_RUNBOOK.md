# Free installation runbook

Use this checklist when you honour a “free installation” offer. The software already includes `docker/install.sh`; this is the human process.

## Before the call

- Buyer has a Ubuntu 24.04 VPS (2 GB RAM minimum; 4 GB preferred) and a domain pointed at it
- Buyer has Stripe, Google Maps, and Twilio accounts (or you create them together)
- You have SSH access they granted for the install window

## Install

1. SSH in and clone the repo
2. `bash ryvo-admin/docker/install.sh`
3. Replace Firebase JSON if they have it; otherwise leave push for a follow-up
4. Confirm `https://domain/api/v1/health` and admin login
5. Seed login works; force a password change
6. Settings: currency, commission vs subscription, Maps, Stripe pk
7. Configure Flutter apps with `scripts/configure-apps.sh` and hand over the APK/IPA commands
8. Optional: Twilio WhatsApp webhook

## Handover

Send the buyer:

- Admin URL and new password they chose
- API URL
- WhatsApp and Stripe webhook URLs
- `whitelabel.env` they should keep private
- Link to `INSTALL.md`

Do not keep their Stripe or Twilio secrets after the session.
