#!/bin/bash
# Run on the EC2 server, from the repo root, to ship a new version:
#   bash docker/redeploy.sh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Pulling latest code"
git pull

echo "==> Rebuilding and restarting containers"
docker compose -f docker/docker-compose.prod.yml up -d --build

echo "==> Pruning old images"
docker image prune -f

echo "==> Done. Tail logs with: docker compose -f docker/docker-compose.prod.yml logs -f"
