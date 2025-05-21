#!/usr/bin/env bash
set -euo pipefail

# → Basis-Pfad (anpassbar mit -p)
INSTALL_DIR="/opt/moodle-docker"
COMPOSE_DIR="$INSTALL_DIR/docker"
ENV_FILE="$COMPOSE_DIR/.env"
DUMPS_DIR="$INSTALL_DIR/dumps"

# → Docker-Compose prüfen
if command -v docker &>/dev/null && docker compose version &>/dev/null; then
  DCMD="docker compose"
elif command -v docker-compose &>/dev/null; then
  DCMD="docker-compose"
else
  echo "Error: Weder 'docker compose' noch 'docker-compose' gefunden." >&2
  exit 1
fi

# → Optionen
usage(){
  echo "Usage: $(basename "$0") [-p install_dir] <backup_dir>"; exit 1
}
while getopts "p:" opt; do
  case $opt in
    p) INSTALL_DIR="$OPTARG"; COMPOSE_DIR="$INSTALL_DIR/docker"; DUMPS_DIR="$INSTALL_DIR/dumps" ;;
    *) usage ;;
  esac
done
shift $((OPTIND-1))
[[ $# -eq 1 ]] || usage

# → Backup-Pfad ermitteln
INPUT="$1"
[[ -d "$INPUT" ]] || INPUT="$DUMPS_DIR/$INPUT"
[[ -d "$INPUT" ]] || { echo "Backup nicht gefunden: $1"; exit 1; }

# → .env laden
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
else
  echo ".env nicht gefunden unter $ENV_FILE" >&2
  exit 1
fi

# → Container runterfahren
echo "Stopping containers…"
pushd "$COMPOSE_DIR" >/dev/null
$DCMD down
popd >/dev/null

# → DB-Restore
echo "Restoring DB…"
docker exec -i moodle-db \
  mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" \
  < "$INPUT/moodle_db.sql"

# → moodledata zurückkopieren
echo "Restoring moodledata…"
rm -rf "$INSTALL_DIR/moodledata"
rsync -a "$INPUT/moodledata/" "$INSTALL_DIR/moodledata/"

# → Container wieder hochfahren
echo "Starting containers…"
pushd "$COMPOSE_DIR" >/dev/null
$DCMD up -d
popd >/dev/null

echo "Restore abgeschlossen von: $INPUT"
