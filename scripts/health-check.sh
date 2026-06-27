#!/bin/bash

ERRORS=0

check_service() {
  local name=$1
  local url=$2
  if curl -sf "$url" > /dev/null 2>&1; then
    echo "  $name: OK"
  else
    echo "  $name: FAIL"
    ERRORS=$((ERRORS + 1))
  fi
}

echo "=== Vetra Health Check ==="
echo "Time: $(date)"
echo ""

echo "Services:"
check_service "Backend API" "http://localhost/q/health/ready"
check_service "Frontend" "http://localhost/app/"
check_service "Landing" "http://localhost/"
check_service "Keycloak" "http://localhost/auth/"
check_service "Grafana" "http://localhost/grafana/api/health"

echo ""
echo "Docker containers:"
docker compose -f /opt/vetra/app/infra/prod/docker-compose.prod.yml ps --format "table {{.Name}}\t{{.Status}}"

echo ""
if [ $ERRORS -eq 0 ]; then
  echo "Result: ALL OK"
  exit 0
else
  echo "Result: $ERRORS service(s) failing"
  exit 1
fi
