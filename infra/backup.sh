#!/usr/bin/env bash
# Daily DB backup: pg_dump (inside the db container) | gzip -> /var/backups,
# then push to S3-compatible object storage, then prune anything older than
# 30 days. Installed on the VPS host via crontab (see infra/README.md) —
# this is OS-level infra scheduling, not application background-job logic.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load prod env: BACKUP_BUCKET, S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY, ...
set -a
# shellcheck source=/dev/null
source "$DIR/.env.prod"
set +a

# aws-cli reads the standard AWS_* names; map from our S3_* env contract.
export AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY"

STAMP=$(date +%F)
BACKUP_DIR=/var/backups
FILE="$BACKUP_DIR/english-app-$STAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

docker compose -f "$DIR/docker-compose.prod.yml" --env-file "$DIR/.env.prod" exec -T db \
  pg_dump -U app english_app | gzip > "$FILE"

aws s3 cp "$FILE" "s3://$BACKUP_BUCKET/db/" --endpoint-url "$S3_ENDPOINT"

find "$BACKUP_DIR" -name 'english-app-*.sql.gz' -mtime +30 -delete
