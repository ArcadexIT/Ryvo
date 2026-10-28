#!/usr/bin/env bash
# One-command RYVO server install. Run from the repo:
#   bash ryvo-admin/docker/install.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCKER_DIR="$ROOT/docker"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

prompt() {
  local label="$1"
  local default="${2:-}"
  local secret="${3:-}"
  local value=""
  if [[ -n "$default" ]]; then
    if [[ "$secret" == "1" ]]; then
      read -r -s -p "$label [$default]: " value || true
      echo
    else
      read -r -p "$label [$default]: " value || true
    fi
    echo "${value:-$default}"
  else
    if [[ "$secret" == "1" ]]; then
      read -r -s -p "$label: " value || true
      echo
    else
      read -r -p "$label: " value || true
    fi
    echo "$value"
  fi
}

rand() {
  openssl rand -hex 24
}

echo "==> RYVO installer"
if ! need_cmd docker; then
  echo "==> Installing Docker"
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "${USER:-root}" || true
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is required."
  exit 1
fi

DOMAIN="$(prompt 'Public domain (example.com)' 'localhost')"
ADMIN_PHONE="$(prompt 'Admin phone' '+01754713136')"
MAP_KEY="$(prompt 'Google Maps API key')"
STRIPE_SECRET="$(prompt 'Stripe secret key (sk_...)' '' 1)"
STRIPE_PK="$(prompt 'Stripe publishable key (pk_...)')"
TWILIO_SID="$(prompt 'Twilio Account SID')"
TWILIO_TOKEN="$(prompt 'Twilio Auth Token' '' 1)"
TWILIO_FROM="$(prompt 'Twilio SMS from-number or Messaging Service SID')"
TWILIO_WA="$(prompt 'Twilio WhatsApp from-number (optional)')"
OPENAI_KEY="$(prompt 'OpenAI API key for WhatsApp bot (optional)' '' 1)"
POSTGRES_PASSWORD="$(prompt 'Postgres password' "$(rand)")"
JWT_ACCESS="$(rand)"
JWT_REFRESH="$(rand)"

SCHEME="https"
if [[ "$DOMAIN" == "localhost" ]]; then
  SCHEME="http"
fi
API_URL="${SCHEME}://${DOMAIN}/api/v1"
WS_URL="${SCHEME}://${DOMAIN}"

mkdir -p "$DOCKER_DIR"
cat > "$DOCKER_DIR/.env" <<EOF
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
NEXT_PUBLIC_MAP_API_KEY=${MAP_KEY}
PUBLIC_API_URL=${API_URL}
PUBLIC_WS_URL=${WS_URL}
EOF

cat > "$ROOT/apps/api/.env.production" <<EOF
DATABASE_URL=postgresql://ryvo:${POSTGRES_PASSWORD}@postgres:5432/ryvo?schema=public
REDIS_URL=redis://redis:6379
JWT_ACCESS_SECRET=${JWT_ACCESS}
JWT_REFRESH_SECRET=${JWT_REFRESH}
PORT=4000
CORS_ORIGINS=${SCHEME}://${DOMAIN}
STRIPE_SECRET_KEY=${STRIPE_SECRET}
TWILIO_ACCOUNT_SID=${TWILIO_SID}
TWILIO_AUTH_TOKEN=${TWILIO_TOKEN}
TWILIO_PHONE_NUMBER=${TWILIO_FROM}
TWILIO_WHATSAPP_FROM=${TWILIO_WA}
OPENAI_API_KEY=${OPENAI_KEY}
GOOGLE_APPLICATION_CREDENTIALS=./firebase-service-account.json
NODE_ENV=production
EOF

if [[ ! -f "$ROOT/apps/api/firebase-service-account.json" ]]; then
  echo '{}' > "$ROOT/apps/api/firebase-service-account.json"
  echo "Wrote an empty Firebase placeholder. Replace apps/api/firebase-service-account.json before push notifications will work."
fi

echo "==> Starting stack"
cd "$DOCKER_DIR"
docker compose -f docker-compose.prod.yml up -d --build

echo
echo "RYVO is starting."
echo "  Admin:  ${SCHEME}://${DOMAIN}"
echo "  API:    ${API_URL}"
echo "  Health: ${API_URL}/health"
echo "  Default admin login: ${ADMIN_PHONE} / 123456  (change this immediately)"
echo
echo "Set Google Maps and Stripe publishable keys in Admin → Settings if you skipped them here."
echo "Point the Flutter apps with scripts/configure-apps.sh after this server is reachable."
echo "WhatsApp webhook: ${API_URL}/webhooks/whatsapp"
echo "Stripe webhook:   ${API_URL}/webhooks/stripe"
