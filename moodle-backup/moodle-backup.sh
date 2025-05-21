#!/usr/bin/env bash
set -euo pipefail

# ---- Default-Konfiguration ----
BASE_DIR="/opt/moodle-docker"          # Basisverzeichnis der Docker-Umgebung :contentReference[oaicite:0]{index=0}
DUMPS_DIR="$BASE_DIR/dumps"            # Hier liegen die Backups :contentReference[oaicite:1]{index=1}

# ---- Optionen parsen ----
FULL=false
INCR=false

usage() {
  echo "Usage: $(basename "$0") [-p base_path] (-f | -i)"
  echo "  -p base_path   Pfad zur Moodle-Docker-Umgebung (default: $BASE_DIR)"
  echo "  -f             Full-Backup"
  echo "  -i             Incrementelles Backup"
  exit 1
}

while getopts ":p:fi" opt; do
  case $opt in
    p) BASE_DIR="$OPTARG"; DUMPS_DIR="$BASE_DIR/dumps" ;;
    f) FULL=true ;;
    i) INCR=true ;;
    *) usage ;;
  esac
done

if ! $FULL && ! $INCR; then
  echo "Error: bitte -f oder -i angeben."
  usage
fi
if $FULL && $INCR; then
  echo "Error: -f und -i gleichzeitig nicht möglich."
  usage
fi

# ---- Versions- und Zeitstempel ermitteln ----
VERSION_FILE="$BASE_DIR/moodle/version.php"
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "version.php nicht gefunden: $VERSION_FILE" >&2
  exit 1
fi
MOODLE_VERSION=$(sed -n "s/.*\$release *= *'\([0-9\.]*\)'.*/\1/p" "$VERSION_FILE")
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

TYPE=$($FULL && echo full || echo incremental)
TARGET_DIR="$DUMPS_DIR/${MOODLE_VERSION}_${TIMESTAMP}_${TYPE}"
mkdir -p "$TARGET_DIR"

# ---- Moodle-Web-Container stoppen ----
echo "Stopping Moodle-Web container…"
cd "$BASE_DIR"
docker compose stop moodle

# ---- Datenbank-Dump ----
echo "Dumping Moodle-DB…"
# nutzt den MariaDB-Container (container_name: moodle-db)
docker exec -T moodle-db \
  mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  > "$TARGET_DIR/moodle_db.sql"

# ---- moodledata sichern ----
echo "Backing up moodledata ($TYPE)…"
if $FULL; then
  rsync -ah --delete "$BASE_DIR/moodledata/" "$TARGET_DIR/moodledata/"
else
  # letztes Full-Backup finden
  LAST_FULL=$(ls -1d "$DUMPS_DIR"/${MOODLE_VERSION}_*"_full" 2>/dev/null | sort | tail -n1 || true)
  if [[ -z "$LAST_FULL" ]]; then
    echo "Kein vorheriges Full-Backup gefunden – führe Full-Backup aus." >&2
    exit 1
  fi
  rsync -ah --link-dest="$LAST_FULL/moodledata" \
    "$BASE_DIR/moodledata/" "$TARGET_DIR/moodledata"
fi

# ---- Moodle-Web-Container wieder starten ----
echo "Starting Moodle-Web container…"
docker compose up -d moodle

echo "Backup ($TYPE) completed in: $TARGET_DIR"
