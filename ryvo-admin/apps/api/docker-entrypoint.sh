#!/bin/sh
set -e

SCHEMA=/app/packages/database/prisma/schema.prisma

echo "Syncing database schema (prisma db push)..."
# Migration history in this repo is incomplete for greenfield installs
# (0_init only enables PostGIS). Push the current Prisma schema instead.
npx prisma db push --schema="$SCHEMA" --skip-generate --accept-data-loss=false

echo "Seeding countries..."
npx tsx /app/packages/database/prisma/seed-countries.ts

echo "Starting API..."
exec "$@"
