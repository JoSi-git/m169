#!/bin/bash

# Moodle Docker backup script (Interactive & CLI-args)
# Author: JoSi
# Last Update: 2025-05-26

clear

# Title (only shown if interactive)
if [ -t 1 ]; then
  gum style --border normal --margin "1" --padding "1 2" --border-foreground 33 "Moodle Docker Backup Tool"
fi

# Function to print messages in bold
print_cmsg() {
  if [[ "$1" == "-n" ]]; then shift; echo -ne "\e[1m$*\e[0m"; else echo -e "\e[1m$*\e[0m"; fi
}

# Load environment variables from .env
if [[ -f "./.env" ]]; then
  source "./.env"
  print_cmsg ".env file found and loaded from local directory."
else
  print_cmsg ".env file wasn't found in local directory. Exiting."
  exit 1
fi

# Default mode
MODE="interactive"

# Argument parsing
case "$1" in
  --db-only)
    MODE="db"
    ;;
  --moodle-only)
    MODE="moodle"
    ;;
  --full)
    MODE="full"
    ;;
  --help)
    echo "Usage: $0 [--full | --db-only | --moodle-only]"
    exit 0
    ;;
  "")
    MODE="interactive"
    ;;
  *)
    echo "Invalid argument: $1"
    exit 1
    ;;

esac

# Interactive menu if no parameter was given
if [[ "$MODE" == "interactive" ]]; then
MODE=$(gum choose --cursor ">" --limit 1 \
    --header "$MENU_HEADER" \
    --header-foreground 15 \
    "Full backup (DB + moodledata)" \
    "Only database" \
    "Only moodledata" \
    "Exit")

  case "$MODE" in
    "Full backup (DB + moodledata)") MODE="full";;
    "Only database") MODE="db";;
    "Only moodledata") MODE="moodle";;
    "Exit") echo "Exiting..."; exit 0;;
    *) echo "Invalid selection. Exiting."; exit 1;;
  esac
fi

# Stop Apache
print_cmsg "\nStopping web server in container '$CONTAINER_MOODLE'..."
docker exec "$CONTAINER_MOODLE" service apache2 stop

# Get Moodle version from inside the container
MOODLE_VERSION=$(docker exec "$CONTAINER_MOODLE" \
  bash -c "sed -n \"s/.*\\\$release *= *'\([0-9.]*\).*/\1/p\" /var/www/html/version.php")

# Generate timestamp and filename with suffix based on MODE
TIMESTAMP=$(date "+%Y%m%d-%H%M")

case "$MODE" in
  full)
    SUFFIX="FULL"
    ;;
  moodle)
    SUFFIX="MOODLE"
    ;;
  db)
    SUFFIX="DUMP"
    ;;
  *)
    SUFFIX="BACKUP"
    ;;
esac

FILENAME="${MOODLE_VERSION}_${TIMESTAMP}_${SUFFIX}.tar.gz"

# Paths
TMP_DIR=$(mktemp -d)

# Backup DB
if [[ "$MODE" == "db" || "$MODE" == "full" ]]; then
  print_cmsg "\nCreating database dump from container '$CONTAINER_DB'..."
  docker exec "$CONTAINER_DB" \
    bash -c "mysqldump -u$MYSQL_ROOT_USER -p'$MYSQL_ROOT_PASSWORD' $MYSQL_DATABASE > /tmp/dump.sql"
  docker cp "$CONTAINER_DB":/tmp/dump.sql "$TMP_DIR/db.sql"
fi

# Backup Moodle web files
if [[ "$MODE" == "moodle" || "$MODE" == "full" ]]; then
  print_cmsg "Copying Moodle files from container '$CONTAINER_MOODLE'..."
  docker cp "$CONTAINER_MOODLE":/var/www/html "$TMP_DIR/moodle"
fi

# Create archive properly without `./` as root folder
print_cmsg "Creating archive..."
tar -czf "$BACKUP_DIR/$FILENAME" -C "$TMP_DIR" "${FILES_TO_ARCHIVE[@]}"

# Cleanup
rm -rf "$TMP_DIR"

# Restart Apache
print_cmsg "Starting web server in container '$CONTAINER_MOODLE'..."
docker exec "$CONTAINER_MOODLE" service apache2 start

# Done
print_cmsg "Backup complete: $BACKUP_DIR/$FILENAME"
