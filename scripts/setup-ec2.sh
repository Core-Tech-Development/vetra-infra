#!/bin/bash
# =============================================================================
# Vetra EC2 Setup Script
# Run on a fresh Ubuntu 24.04 EC2 instance
# Usage: chmod +x setup-ec2.sh && sudo ./setup-ec2.sh
# =============================================================================

set -euo pipefail

echo "=== Vetra EC2 Setup ==="

# ---------------------------------------------------------------------------
# 1. System updates
# ---------------------------------------------------------------------------
echo "[1/7] Updating system..."
apt-get update -y
apt-get upgrade -y

# ---------------------------------------------------------------------------
# 2. Install Docker
# ---------------------------------------------------------------------------
echo "[2/7] Installing Docker..."
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# ---------------------------------------------------------------------------
# 3. Clone vetra-infra
# ---------------------------------------------------------------------------
echo "[3/7] Setting up /opt/vetra..."
mkdir -p /opt/vetra
cd /opt/vetra
git clone https://github.com/Core-Tech-Development/vetra-infra.git .

# ---------------------------------------------------------------------------
# 4. Generate .env with random passwords
# ---------------------------------------------------------------------------
echo "[4/7] Generating .env with random passwords..."

generate_password() {
    openssl rand -base64 24 | tr -d '=/+' | head -c 32
}

cat > /opt/vetra/.env << EOF
# Auto-generated on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
POSTGRES_USER=vetra
POSTGRES_PASSWORD=$(generate_password)
POSTGRES_DB=vetra

KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=$(generate_password)

MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=$(generate_password)

GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=$(generate_password)

GHCR_TOKEN=REPLACE_WITH_GITHUB_PAT
EOF

chmod 600 /opt/vetra/.env

echo ""
echo "=== IMPORTANT ==="
echo "Generated passwords saved to /opt/vetra/.env"
echo "Please save these credentials securely!"
echo ""
cat /opt/vetra/.env
echo ""
echo "================="

# ---------------------------------------------------------------------------
# 5. Login to GitHub Container Registry
# ---------------------------------------------------------------------------
echo "[5/7] GitHub Container Registry login..."
echo "You need to update GHCR_TOKEN in /opt/vetra/.env with a valid GitHub PAT"
echo "Then run: echo \$GHCR_TOKEN | docker login ghcr.io -u USERNAME --password-stdin"

# ---------------------------------------------------------------------------
# 6. Pull images and start services
# ---------------------------------------------------------------------------
echo "[6/7] Starting services (infrastructure only for now)..."
cd /opt/vetra
docker compose up -d postgres keycloak minio otel-collector tempo prometheus loki promtail grafana nginx certbot

# ---------------------------------------------------------------------------
# 7. SSL certificates
# ---------------------------------------------------------------------------
echo "[7/7] SSL certificate setup..."
echo ""
echo "After DNS is configured and propagated, run:"
echo ""
echo "  docker compose run --rm certbot certonly \\"
echo "    --webroot -w /var/www/certbot \\"
echo "    -d vetra.vet.br \\"
echo "    -d app.vetra.vet.br \\"
echo "    -d api.vetra.vet.br \\"
echo "    -d auth.vetra.vet.br \\"
echo "    --email YOUR_EMAIL \\"
echo "    --agree-tos --no-eff-email"
echo ""
echo "Then reload nginx:"
echo "  docker compose exec nginx nginx -s reload"
echo ""

# Cron for SSL renewal (every 12 hours)
echo "0 */12 * * * cd /opt/vetra && docker compose run --rm certbot renew --quiet && docker compose exec nginx nginx -s reload" | crontab -

echo "=== Setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Update GHCR_TOKEN in /opt/vetra/.env"
echo "  2. Run: echo \$GHCR_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin"
echo "  3. Configure DNS A records pointing to this server's IP"
echo "  4. Pull app images: docker compose pull backend frontend landing"
echo "  5. Start all: docker compose up -d"
echo "  6. Generate SSL certificates (see command above)"
