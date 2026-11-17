#!/usr/bin/env bash
# Build a CodeCanyon upload zip. Does not modify the working tree.
# Output: dist/ryvo-codecanyon-1.0.0.zip
#
# The zip excludes git history, dependencies, build output, env files,
# keystores, and the author's Firebase project files. Buyers generate
# their own Firebase files. See documentation/index.html.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="ryvo"
OUT_DIR="$ROOT/dist"
STAGE="$OUT_DIR/.stage"
ZIP="$OUT_DIR/ryvo-codecanyon-1.0.0.zip"

cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

rm -rf "$STAGE"
mkdir -p "$STAGE/$NAME" "$OUT_DIR"

rsync -a \
  --exclude '.git/' \
  --exclude '.cursor/' \
  --exclude '.cursorignore' \
  --exclude 'dist/' \
  --exclude 'node_modules/' \
  --exclude '.dart_tool/' \
  --exclude 'build/' \
  --exclude '.next/' \
  --exclude '.turbo/' \
  --exclude 'coverage/' \
  --exclude '.gradle/' \
  --exclude 'Pods/' \
  --exclude '.symlinks/' \
  --exclude 'ephemeral/' \
  --exclude 'DerivedData/' \
  --exclude '.idea/' \
  --exclude '.vscode/' \
  --exclude '.env' \
  --exclude '.env.*' \
  --exclude 'whitelabel.env' \
  --exclude 'google-services.json' \
  --exclude 'GoogleService-Info.plist' \
  --exclude 'firebase_options.dart' \
  --exclude 'firebase-service-account.json' \
  --exclude '*.jks' \
  --exclude '*.keystore' \
  --exclude 'key.properties' \
  --exclude '*.apk' \
  --exclude '*.aab' \
  --exclude '*.ipa' \
  --exclude '*.pem' \
  --exclude 'caseimage/' \
  --exclude '.DS_Store' \
  "$ROOT/" "$STAGE/$NAME/"

# .env.example files are named .env.example, which the '.env.*' exclude drops.
# Copy them back so buyers have the templates.
while IFS= read -r example; do
  rel="${example#"$ROOT"/}"
  mkdir -p "$STAGE/$NAME/$(dirname "$rel")"
  cp "$example" "$STAGE/$NAME/$rel"
done < <(find "$ROOT" \
  \( -name node_modules -o -name .git -o -name Pods -o -name build -o -name .dart_tool -o -name dist -o -name .gradle \) -prune \
  -o -name '.env.example' -print)

# Strip live endpoints and keys from the copy buyers receive.
# The working tree is not edited.
find "$STAGE/$NAME" -type f \( \
  -name '*.dart' -o -name '*.xml' -o -name '*.plist' -o -name '*.ts' -o -name '*.tsx' \
  -o -name '*.kt' -o -name '*.kts' -o -name '*.swift' -o -name '*.m' -o -name '*.gradle' \
  -o -name '*.json' -o -name '*.md' -o -name '*.html' -o -name '*.example' \
  -o -name '*.sh' -o -name '*.yml' -o -name '*.yaml' \
  \) -print0 | xargs -0 perl -pi -e '
    s#https://ryvo\.arcadexit\.com#https://your-domain.com#g;
    s/AIza[0-9A-Za-z_\-]{20,}/YOUR_GOOGLE_MAPS_API_KEY/g;
    s/pk_(test|live)_[0-9A-Za-z]+/xxxxxxxx_me/g;
    s/sk_(test|live)_[0-9A-Za-z]+/xxxxxxxx_me/g;
  '

rm -f "$ZIP"
(
  cd "$STAGE"
  zip -r -q "$ZIP" "$NAME"
)

echo "Wrote $ZIP"
echo "Open documentation/index.html inside the zip and follow Server installation."
