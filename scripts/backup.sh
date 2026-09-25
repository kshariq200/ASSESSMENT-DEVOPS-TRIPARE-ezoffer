#!/usr/bin/env bash
set -euo pipefail

# Loads MYSQL_* variables from .env if present.
if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

CONTAINER="hotel-booking-mysql"
DB_NAME="${MYSQL_DATABASE:-hotel_booking_db}"
ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is not set (copy .env.example to .env and fill it in)}"

BACKUP_DIR="backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.sql"

echo "Backing up database '${DB_NAME}' from container '${CONTAINER}'..."

if ! docker exec -e MYSQL_PWD="${ROOT_PASSWORD}" "${CONTAINER}" \
    mysqldump -u root --single-transaction --routines --triggers "${DB_NAME}" > "${BACKUP_FILE}"; then
  echo "Backup failed" >&2
  rm -f "${BACKUP_FILE}"
  exit 1
fi

if [ ! -s "${BACKUP_FILE}" ]; then
  echo "Backup file is empty, treating as failure" >&2
  rm -f "${BACKUP_FILE}"
  exit 1
fi

echo "Backup created: ${BACKUP_FILE}"
