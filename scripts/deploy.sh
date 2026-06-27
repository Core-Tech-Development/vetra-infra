#!/bin/bash
set -euo pipefail

APP_DIR="/opt/vetra/app"
COMPOSE_FILE="infra/prod/docker-compose.prod.yml"
ENV_FILE="infra/prod/.env.prod"

cd "$APP_DIR"

echo "[$(date)] Starting deploy..."

# Pull latest code
git pull origin main

# Load env vars
set -a && source "$ENV_FILE" && set +a

# Build and deploy
docker compose -f "$COMPOSE_FILE" build
docker compose -f "$COMPOSE_FILE" up -d --remove-orphans

# Cleanup
docker image prune -f

echo "[$(date)] Deploy completed."

# Health check
echo "Waiting for services..."
sleep 15
if curl -sf http://localhost/q/health/ready > /dev/null 2>&1; then
  echo "Health check: OK"
else
  echo "Health check: FAIL - check logs with: docker compose -f $COMPOSE_FILE logs"
  exit 1
fi
