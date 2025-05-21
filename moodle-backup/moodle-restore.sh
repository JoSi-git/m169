#!/usr/bin/env bash
set -euo pipefail

# ---- Default-Konfiguration ----
BASE_DIR="/opt/moodle-docker"
DUMPS_DIR="$BASE_DIR/dumps"

# ---- Optionen parsen ----
usage() {
  echo "Usage: $(basename "$0") [-p base_path] <backup_dir>"
  echo "  -p base_path   Pfad zur Moodle-Docker-Umgebung (default: $BASE_DIR)"
  echo "  <backup_dir>   Verzeichnis des Backups (voller Pfad oder relativ zu $DUMPS_DIR)"
  exit 1
}

while getopts ":p:" opt; do
  case $opt in
    p) BASE_DIR="$OPTARG"; DUMPS_DIR="$BASE_DIR/dumps" ;;
    *) usage ;;
  esac
done
shift $((OPTIND-1))
if [[ $# -ne 1 ]]; then
  usage
fi

# ---- Backup-Verzeichnis ermitteln ----
INPUT="$1"
if [[ ! -d "$INPUT" ]]; then
  INPUT="$DUMPS_DIR/$INPUT"
fi
if [[ ! -d "$INPUT" ]]; then
  echo "Backup-Verzeichnis nicht gefunden: $INPUT" >&2
  exit 1
fi

# ---- Container runterfahren ----
echo "Stopping all Moodle containers…"
cd "$BASE_DIR"
docker compose down

# ---- Daten zurückspielen ----
echo "Restoring DB…"
docker exec -i moodle-db \
  mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  < "$INPUT/moodle_db.sql"

echo "Restoring moodledata…"
rm -rf "$BASE_DIR/moodledata"
rsync -ah "$INPUT/moodledata/" "$BASE_DIR/moodledata/"

# ---- Container wieder hochfahren ----
echo "Starting Moodle containers…"
docker compose up -d

echo "Restore completed from: $INPUT"
