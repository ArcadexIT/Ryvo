# Ryvo

Ride, bid, and parcel marketplace: customer app, driver app, API, and admin panel.

**Installation and user guide:** open [`documentation/index.html`](documentation/index.html) in a browser. That is the CodeCanyon manual (server install, HTTPS, mobile builds, admin, Maps, Stripe, Firebase). Changelog: [`changelog.txt`](changelog.txt).

To build the upload zip (excludes dependencies, secrets, and the Firebase project files):

```bash
bash scripts/package-codecanyon.sh
```

## Layout

| Path | What it is |
|------|------------|
| `ryvo-customer/` | Flutter app for customers |
| `ryvo-driver/` | Flutter app for providers |
| `ryvo-admin/` | NestJS API, Next.js admin, and Prisma database |
| `scripts/` | Shared build config for both mobile apps |
| `Ryvo logos/` | Brand assets |

## Backend and admin

Setup, local development, and production install live in [ryvo-admin/README.md](ryvo-admin/README.md) and [ryvo-admin/docs/INSTALL.md](ryvo-admin/docs/INSTALL.md).

## Mobile apps

```bash
cp scripts/whitelabel.env.example scripts/whitelabel.env
bash scripts/configure-apps.sh
```

Edit `scripts/whitelabel.env` with the API URL and keys. That file stays on your machine and is not committed.
