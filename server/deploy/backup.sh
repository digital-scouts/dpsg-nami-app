#!/usr/bin/env bash
# Taegliches MongoDB-Backup des Statistikservers, per Cron als deploy-User:
#   15 3 * * * /opt/nami-statistics/backup.sh >> /opt/nami-statistics/backups/backup.log 2>&1
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/nami-statistics}"
BACKUP_DIR="${BACKUP_DIR:-${APP_DIR}/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
DATABASE="${DATABASE:-nami_statistics}"

compose() {
  docker compose -p nami-statistics --env-file "${APP_DIR}/.env" -f "${APP_DIR}/docker-compose.server.yml" "$@"
}

mkdir -p "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
target="${BACKUP_DIR}/${DATABASE}_${timestamp}.archive.gz"

# Zugangsdaten werden im Container aus dessen Umgebung gelesen und erscheinen nicht in der Prozessliste des Hosts.
compose exec -T -e DATABASE="${DATABASE}" mongodb sh -c \
  'mongodump --quiet --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --db "$DATABASE" --archive --gzip' \
  > "${target}"

if [ ! -s "${target}" ]; then
  echo "$(date -u +%FT%TZ) Backup fehlgeschlagen: ${target} ist leer" >&2
  rm -f "${target}"
  exit 1
fi

chmod 600 "${target}"

# Marker fuer /health/ready und den taeglichen Status-Check.
compose exec -T -e DATABASE="${DATABASE}" mongodb sh -c \
  'mongosh --quiet --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin "$DATABASE" --eval "db.ops_status.updateOne({ _id: \"backup\" }, { \$set: { last_success_at: new Date() } }, { upsert: true })"' \
  > /dev/null

find "${BACKUP_DIR}" -name "${DATABASE}_*.archive.gz" -mtime "+${RETENTION_DAYS}" -delete

echo "$(date -u +%FT%TZ) Backup erstellt: ${target}"
