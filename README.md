# Ryvo

Roadside assistance marketplace: customer app, provider app, API, and admin panel in one repo.

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
