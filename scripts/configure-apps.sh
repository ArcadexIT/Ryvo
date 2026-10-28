#!/usr/bin/env bash
# Configure Flutter customer and driver apps from a small env file, then print
# the ready-to-run build commands.
#
#   cp scripts/whitelabel.env.example scripts/whitelabel.env
#   bash scripts/configure-apps.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${1:-$ROOT/scripts/whitelabel.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  echo "Copy scripts/whitelabel.env.example and fill in your API URL and keys."
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

API_BASE_URL="${API_BASE_URL:?Set API_BASE_URL}"
WS_BASE_URL="${WS_BASE_URL:-}"
MAPS_API_KEY="${MAPS_API_KEY:-}"
APP_NAME="${APP_NAME:-Ryvo}"

echo "Configured:"
echo "  API_BASE_URL=$API_BASE_URL"
echo "  APP_NAME=$APP_NAME"
echo
echo "Customer (Android):"
echo "  cd $ROOT/ryvo-customer && flutter pub get && flutter build apk --release \\"
echo "    --dart-define=API_BASE_URL=$API_BASE_URL \\"
echo "    --dart-define=WS_BASE_URL=${WS_BASE_URL} \\"
echo "    --dart-define=MAPS_API_KEY=${MAPS_API_KEY}"
echo
echo "Driver (Android):"
echo "  cd $ROOT/ryvo-driver && flutter pub get && flutter build apk --release \\"
echo "    --dart-define=API_BASE_URL=$API_BASE_URL \\"
echo "    --dart-define=WS_BASE_URL=${WS_BASE_URL} \\"
echo "    --dart-define=MAPS_API_KEY=${MAPS_API_KEY}"
echo
echo "iOS: the same --dart-define flags with flutter build ipa --release"
echo "Change applicationId / bundle id in android/app/build.gradle and ios/Runner.xcodeproj before store upload."
echo "App display name is currently $APP_NAME in each app's AndroidManifest / Info.plist."
