#!/usr/bin/env bash
set -euo pipefail

# Moodle Docker Restore Script
# Usage: moodle-restore.sh -f <full_name> | -i <incremental_name>
#   -f <name>: full-backup directory (e.g. 4.2.1-20250520-140000-full)
#   -i <name>: incremental-backup directory (e.g. 4.2.1-20250520-140000-incremental)

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"
BACKUP_BASE="$INSTALL_DIR/dumps"

# Parse options
MODE=""
BACKUP_NAME=""
while getopts "f:i:" opt; do
  case $opt in
    f) MODE="full"; BACKUP_NAME="$OPTARG" ;;
    i) MODE="incremental"; BACKUP_NAME="$OPTARG" ;;
    *) echo "Usage: $0 -f <full_name> | -i <incremental_name>"; exit 1 ;;
  esac
done

if [[ -z "$MODE" || -z "$BACKUP_NAME" ]]; then
  echo "Error: specify -f <full_name> or -i <incremental_name>"
  exit 1
fi

BACKUP_DIR="$BACKUP_BASE/$BACKUP_NAME"
if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "Error: backup directory not found: $BACKUP_DIR"
  exit 1
fi

# If incremental, find the matching full backup
if [[ "$MODE" == "incremental" ]]; then
  VERSION="${BACKUP_NAME%%-*}"
  mapfile -t fulls < <(ls -1d "$BACKUP_BASE/${VERSION}-"*"-full" 2>/dev/null | sort)
  if [[ ${#fulls[@]} -eq 0 ]]; then
    echo "Error: kein Full-Backup für Version $VERSION gefunden"
    exit 1
  fi
  FULL_DIR="${fulls[-1]}"
else
  FULL_DIR="$BACKUP_DIR"
fi

# Stop containers
echo "Stopping Moodle containers..."
cd "$INSTALL_DIR"
docker compose down

# Restore database
echo "Restoring database..."
DB_CONTAINER=$(docker compose ps -q db)
docker exec -i "$DB_CONTAINER" \
  mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  < "$BACKUP_DIR/moodle_db.sql"

# Restore moodledata from full
echo "Restoring moodledata from full backup..."
rm -rf "$INSTALL_DIR/moodledata"
mkdir -p "$INSTALL_DIR/moodledata"
tar -xzf "$FULL_DIR/moodledata-full.tar.gz" -C "$INSTALL_DIR"

# Apply incremental if requested
if [[ "$MODE" == "incremental" ]]; then
  echo "Applying incremental backup..."
  tar -xzf "$BACKUP_DIR/moodledata-incremental.tar.gz" -C "$INSTALL_DIR"
fi

# Fix permissions
echo "Fixing permissions..."
chown -R 33:33 "$INSTALL_DIR/moodledata"

# Start containers
echo "Starting Moodle containers..."
docker compose up -d

echo "Restore ($MODE) completed from: $BACKUP_NAME"
