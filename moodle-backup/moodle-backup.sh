#!/usr/bin/env bash
set -euo pipefail

# Moodle Docker Backup Script
# Usage: moodle-backup.sh [-f | -i]
#   -f: full backup
#   -i: incremental backup

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"
BACKUP_BASE="$INSTALL_DIR/dumps"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
MOODLE_VERSION=$(docker compose -f "$INSTALL_DIR/docker-compose.yml" \
  exec -T app bash -lc "grep \"\$release\" /var/www/html/version.php | sed -n \"s/.*'\\([0-9.]*\\)'.*/\\1/p\"")

# Parse options
BACKUP_MODE=""
while getopts "fi" opt; do
  case $opt in
    f) BACKUP_MODE="full" ;;
    i) BACKUP_MODE="incremental" ;;
    *) echo "Usage: $0 [-f|-i]"; exit 1 ;;
  esac
done

if [[ -z "$BACKUP_MODE" ]]; then
  echo "Error: specify -f (full) or -i (incremental)"
  exit 1
fi

# Prepare destination
DEST_DIR="$BACKUP_BASE/${MOODLE_VERSION}-${TIMESTAMP}-${BACKUP_MODE}"
mkdir -p "$DEST_DIR"

# Stop containers
echo "Stopping Moodle containers..."
cd "$INSTALL_DIR"
docker compose down

# Dump database
echo "Dumping database..."
DB_CONTAINER=$(docker compose ps -q db)
docker exec -i "$DB_CONTAINER" \
  mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  > "$DEST_DIR/moodle_db.sql"

# Backup moodledata
echo "Backing up moodledata ($BACKUP_MODE)..."
SNAR_FILE="$SCRIPT_DIR/backup.snar"
if [[ "$BACKUP_MODE" == "full" ]]; then
  tar --create --gzip --file="$DEST_DIR/moodledata-full.tar.gz" \
      --listed-incremental="$SNAR_FILE" -C "$INSTALL_DIR" moodledata
else
  tar --create --gzip --file="$DEST_DIR/moodledata-incremental.tar.gz" \
      --listed-incremental="$SNAR_FILE" -C "$INSTALL_DIR" moodledata
fi

# Restart containers
echo "Starting Moodle containers..."
docker compose up -d

echo "Backup ($BACKUP_MODE) completed: $DEST_DIR"
