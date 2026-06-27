#!/bin/bash
set -euo pipefail

BACKUP_DIR="/opt/vetra/backups/postgres"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/vetra_$TIMESTAMP.sql.gz"

echo "[$(date)] Starting PostgreSQL backup..."

# Dump database from Docker container
docker exec vetra-postgres pg_dump -U vetra -d vetra | gzip > "$BACKUP_FILE"

echo "[$(date)] Backup saved: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"

# Remove old backups
find "$BACKUP_DIR" -name "vetra_*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "[$(date)] Cleanup done. Remaining backups:"
ls -lh "$BACKUP_DIR"/vetra_*.sql.gz 2>/dev/null || echo "  (none)"
