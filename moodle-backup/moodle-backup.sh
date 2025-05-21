#!/usr/bin/env bash
set -euo pipefail

# → Basis-Pfade (anpassbar mit -p)
INSTALL_DIR="/opt/moodle-docker"
COMPOSE_DIR="$INSTALL_DIR/docker"
ENV_FILE="$COMPOSE_DIR/.env"
DUMPS_DIR="$INSTALL_DIR/dumps"

# → Docker-Compose-Befehl ermitteln
if command -v docker &>/dev/null && docker compose version &>/dev/null; then
  DCMD="docker compose"
elif command -v docker-compose &>/dev/null; then
  DCMD="docker-compose"
else
  echo "Error: Weder 'docker compose' noch 'docker-compose' gefunden." >&2
  exit 1
fi

# → Optionen
FULL=false; INCR=false
usage(){
  echo "Usage: $(basename "$0") [-p install_dir] (-f | -i)"; exit 1
}
while getopts "p:fi" opt; do
  case $opt in
    p) INSTALL_DIR="$OPTARG"; COMPOSE_DIR="$INSTALL_DIR/docker"; DUMPS_DIR="$INSTALL_DIR/dumps" ;;
    f) FULL=true ;;
    i) INCR=true ;;
    *) usage ;;
  esac
done
if ! $FULL && ! $INCR; then echo "Bitte -f oder -i angeben."; usage; fi
if $FULL && $INCR;  then echo "Nicht beides gleichzeitig."; usage; fi

# → .env laden
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
else
  echo ".env nicht gefunden unter $ENV_FILE" >&2
  exit 1
fi

# → Moodle-Version & Timestamp
VERSION_FILE="$INSTALL_DIR/moodle/version.php"
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "version.php nicht gefunden: $VERSION_FILE" >&2
  exit 1
fi
MOODLE_VERSION=$(sed -n "s/.*\$release *= *'\([0-9\.]*\)'.*/\1/p" "$VERSION_FILE")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TYPE=$($FULL && echo full || echo incremental)

TARGET="$DUMPS_DIR/${MOODLE_VERSION}_${TIMESTAMP}_${TYPE}"
mkdir -p "$TARGET"

# → Container stoppen
echo "Stopping Moodle-Web…"
pushd "$COMPOSE_DIR" >/dev/null
$DCMD stop moodle
popd >/dev/null

# → DB-Dump
echo "Dumping DB…"
docker exec -T moodle-db \
  mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  > "$TARGET/moodle_db.sql"

# → moodledata sichern
echo "Backing up moodledata ($TYPE)…"
if $FULL; then
  rsync -a --delete "$INSTALL_DIR/moodledata/" "$TARGET/moodledata/"
else
  LAST_FULL=$(ls -1d "$DUMPS_DIR"/${MOODLE_VERSION}_*"_full" 2>/dev/null \
              | sort | tail -n1 || true)
  if [[ -z "$LAST_FULL" ]]; then
    echo "Kein Full-Backup gefunden, führe Full-Backup durch." >&2
    exit 1
  fi
  rsync -a --link-dest="$LAST_FULL/moodledata" \
    "$INSTALL_DIR/moodledata/" "$TARGET/moodledata"
fi

# → Container wieder starten
echo "Starting Moodle-Web…"
pushd "$COMPOSE_DIR" >/dev/null
$DCMD up -d moodle
popd >/dev/null

echo "Backup abgeschlossen: $TARGET"
