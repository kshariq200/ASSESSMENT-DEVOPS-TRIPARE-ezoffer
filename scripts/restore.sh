#!/usr/bin/env bash
set -euo pipefail

# Loads MYSQL_* variables from .env if present.
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

CONTAINER="hotel-booking-mysql"
ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is not set (copy .env.example to .env and fill it in)}"
RESTORE_DB_NAME="${MYSQL_DATABASE:-hotel_booking_db}_restore"

BACKUP_FILE="${1:-}"
if [ -z "${BACKUP_FILE}" ]; then
  BACKUP_FILE="$(ls -1t backups/backup_*.sql 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${BACKUP_FILE}" ] || [ ! -f "${BACKUP_FILE}" ]; then
  echo "Usage: $0 <backup-file>  (or run with no argument to use the latest backup in backups/)" >&2
  exit 1
fi

echo "Restoring '${BACKUP_FILE}' into fresh database '${RESTORE_DB_NAME}'..."

docker exec -e MYSQL_PWD="${ROOT_PASSWORD}" "${CONTAINER}" \
  mysql -u root -e "DROP DATABASE IF EXISTS \`${RESTORE_DB_NAME}\`; CREATE DATABASE \`${RESTORE_DB_NAME}\`;"

if ! docker exec -i -e MYSQL_PWD="${ROOT_PASSWORD}" "${CONTAINER}" \
    mysql -u root "${RESTORE_DB_NAME}" < "${BACKUP_FILE}"; then
  echo "Restore failed" >&2
  exit 1
fi

echo "Restore complete into database '${RESTORE_DB_NAME}'."
