#!/bin/bash
set -euo pipefail

BACKUP_DIR="/opt/vetra/backups/minio"
RETENTION_DAYS=30
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/minio_$TIMESTAMP.tar.gz"

echo "[$(date)] Starting MinIO backup..."

# Get the MinIO volume mount path
VOLUME_PATH=$(docker volume inspect vetra-prod_vetra-minio-data --format '{{ .Mountpoint }}' 2>/dev/null || \
  docker volume inspect vetra-minio-data --format '{{ .Mountpoint }}' 2>/dev/null)

if [ -z "$VOLUME_PATH" ]; then
  echo "[$(date)] ERROR: Could not find MinIO volume"
  exit 1
fi

# Create compressed backup
sudo tar -czf "$BACKUP_FILE" -C "$VOLUME_PATH" .

echo "[$(date)] Backup saved: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"

# Remove old backups
find "$BACKUP_DIR" -name "minio_*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "[$(date)] Cleanup done."
