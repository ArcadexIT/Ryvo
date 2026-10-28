# RYVO Platform

Unified backend and admin panel for the RYVO roadside assistance marketplace (Customer + Provider apps).

## Stack

| Layer | Technology |
|-------|------------|
| Admin UI | Next.js 14, Tailwind, TanStack Query |
| API | NestJS, Swagger |
| Database | PostgreSQL + Prisma |
| Cache / Real-time | Redis, WebSocket (Socket.io) |
| Files | AWS S3 (presigned URLs) |
| Payments | Stripe |

## Monorepo structure

```
ryvo-admin/
├── apps/
│   ├── api/          # NestJS REST + WebSocket
│   └── admin/        # Next.js admin panel
├── packages/
│   ├── database/     # Prisma schema, migrations, seed
│   ├── shared/       # Shared enums and types
│   └── tsconfig/     # Shared TS configs
├── docs/             # Backend & admin developer documentation
└── docker/           # Postgres + Redis
```

See [`docs/BACKEND_ADMIN_SPEC.md`](docs/BACKEND_ADMIN_SPEC.md) for the full backend, API, database, and admin panel specification.

## Production install

On a fresh Ubuntu VPS:

```bash
bash docker/install.sh
```

That writes env files, starts Postgres/Redis/API/admin/Caddy, and prints the admin URL. Flutter store builds: `bash ../scripts/configure-apps.sh`. Full steps, WhatsApp/Stripe webhooks, and the free-install runbook: [`docs/INSTALL.md`](docs/INSTALL.md).

## Quick start

### 1. Start infrastructure

```bash
cd docker
docker compose up -d
```

Postgres runs on **port 5433** (not 5432) to avoid conflicts with a local Postgres install.

### 2. Install dependencies

```bash
cd ..
npm install
```

### 3. Configure environment

```bash
cp packages/database/.env.example packages/database/.env
cp apps/api/.env.example apps/api/.env
cp apps/admin/.env.example apps/admin/.env
```

### 4. Database setup

```bash
npm run db:generate
npm run db:push
npm run db:seed
```

### 5. Run development servers

```bash
# Terminal 1 — API (port 4000)
npm run dev --workspace=@ryvo/api

# Terminal 2 — Admin (port 3000)
npm run dev --workspace=@ryvo/admin
```

- **Admin panel:** http://localhost:3000
- **API Swagger:** http://localhost:4000/api/docs
- **Health check:** http://localhost:4000/api/v1/health

## Default credentials (seed)

| Role | Phone | Password |
|------|-------|----------|
| Super Admin | 01754713136 | 123456 |
| Customer (US) | +12345678900 | Customer@123 |
| Customer (UK) | +447700900001 | Customer@123 |
| Provider (US) | +19876543210 | Provider@123 |
| Provider (UK) | +447700900002 | Provider@123 |

## API surfaces

| Prefix | Consumer |
|--------|----------|
| `/api/v1/customer/*` | Flutter customer app |
| `/api/v1/provider/*` | Flutter provider app |
| `/api/v1/admin/*` | Next.js admin panel |
| WebSocket `/tracking` | Live tracking (all apps) |

## Admin modules

- **Dashboard** — KPIs, charts
- **Customers** — list, detail, suspend, wallet adjust
- **Providers** — KYC review, force offline, commission
- **Jobs** — timeline, manual assign, cancel, tracking replay
- **Live Ops** — real-time map via WebSocket
- **Finance** — payments, wallets, earnings, payouts
- **Pricing** — services, rules, promo codes
- **Support** — ticket inbox
- **CMS** — banners, FAQs
- **Settings** — platform config, notification templates
- **Admins** — staff + RBAC
- **Audit** — admin action logs

## Environment variables

See `.env.example` files in:
- `packages/database/.env.example`
- `apps/api/.env.example`
- `apps/admin/.env.example`

## Integration with mobile apps

Point the Flutter customer app (Phase 2) to:
- `POST /api/v1/customer/auth/*`
- `POST /api/v1/customer/jobs`
- WebSocket subscribe to `job:{jobId}` for live tracking

Shared enums live in `packages/shared` — mirror in Flutter as needed.

## Production notes

- Change JWT secrets and admin password before deploy
- Enable Stripe keys for real payments
- Configure AWS S3 bucket for file uploads
- Enable admin 2FA via `POST /admin/auth/2fa/setup`
- All admin write actions are logged in `audit_logs`
