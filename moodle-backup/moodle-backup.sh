#!/bin/bash

# Moodle Docker backup script (Interactive & CLI-args)
# Author: JoSi
# Last Update: 2025-05-26
# Description: Simple terminal backup tool

# Function: Prints the given text in bold on the console
print_cmsg() {
  if [[ "$1" == "-n" ]]; then
    shift
    echo -ne "\e[1m$*\e[0m"
  else
    echo -e "\e[1m$*\e[0m"
  fi
}

# Load environment variables from .env
if [[ -f "./.env" ]]; then
  source "./.env"
  print_cmsg ".env file found and loaded from local directory."
else
  print_cmsg ".env file wasn't found in local directory. Exiting."
  exit 1
fi

# Local Variables
MODE="interactive"
LOG_FILE="$LOG_DIR/moodle-backup/running-backup.log"

# Title (only shown if interactive)
printf '\033[38;5;33mMoodle Docker Backup Tool\n-------------------------------\n\033[0m'

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

# Feedback if a mode was selected via CLI argument
if [[ "$MODE" != "interactive" ]]; then
  case "$MODE" in
    full)
      print_cmsg "Mode: Full backup (DB + Moodle files)" | tee -a "$LOG_FILE"
      ;;
    db)
      print_cmsg "Mode: Only database" | tee -a "$LOG_FILE"
      ;;
    moodle)
      print_cmsg "Mode: Only Moodle files" | tee -a "$LOG_FILE"
      ;;
  esac
fi

if [[ "$MODE" == "interactive" ]]; then
  OPTIONS=(
    "Full backup (DB + moodledata)"
    "Only database"
    "Only moodledata"
    "Exit"
  )


# Display menu with border and numbered list using gum
  gum style --border normal --padding "1 2" --border-foreground 33 <<EOF
What would you like to backup?

$(printf '%s\n' "${OPTIONS[@]}" | nl -w1 -s'. ')
EOF
  echo
  # Prompt user to enter their choice number
  read -p "Enter the number of your choice: " SELECTION

  # Map the numeric choice to the corresponding MODE value
  case "$SELECTION" in
    1) MODE="full" ;;
    2) MODE="db" ;;
    3) MODE="moodle" ;;
    4) echo "Exiting..."; exit 0 ;;
    *) echo "Invalid selection. Exiting."; exit 0 ;;
  esac
fi

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

# Get Moodle version from inside the container
MOODLE_VERSION=$(docker exec "$CONTAINER_MOODLE" \
  bash -c "sed -n \"s/.*\\\$release *= *'\([0-9.]*\).*/\1/p\" /var/www/html/version.php")

# Generate timestamp and filename with suffix based on MODE
TIMESTAMP=$(date "+%Y%m%d-%H%M")
FILENAME="${MOODLE_VERSION}_${TIMESTAMP}_${SUFFIX}.tar.gz"

# Stop Apache
print_cmsg "\nStopping web server in container '$CONTAINER_MOODLE'..." | tee -a "$LOG_FILE"
docker exec "$CONTAINER_MOODLE" service apache2 stop
echo

# Paths
TMP_DIR=$(mktemp -d)

# Backup DB
if [[ "$MODE" == "db" || "$MODE" == "full" ]]; then
  print_cmsg "Creating database dump from container '$CONTAINER_DB'..." | tee -a "$LOG_FILE"
  docker exec "$CONTAINER_DB" \
    bash -c "mysqldump -u$MYSQL_ROOT_USER -p'$MYSQL_ROOT_PASSWORD' $MYSQL_DATABASE > /tmp/dump.sql"
  docker cp "$CONTAINER_DB":/tmp/dump.sql "$TMP_DIR/db.sql"
fi

# Backup Moodle web files
if [[ "$MODE" == "moodle" || "$MODE" == "full" ]]; then
  print_cmsg "Copying Moodle files from container '$CONTAINER_MOODLE'..." | tee -a "$LOG_FILE"
  docker cp "$CONTAINER_MOODLE":/var/www/html "$TMP_DIR/moodle"
fi

# Restart Apache
print_cmsg "Starting web server in container '$CONTAINER_MOODLE'..." | tee -a "$LOG_FILE"
docker exec "$CONTAINER_MOODLE" service apache2 start

# Create archive properly without `./` as root folder
print_cmsg "Creating archive..." | tee -a "$LOG_FILE"

# Prepare list of files to archive
FILES_TO_ARCHIVE=()
if [[ "$MODE" == "db" || "$MODE" == "full" ]]; then
  FILES_TO_ARCHIVE+=("db.sql")
fi
if [[ "$MODE" == "moodle" || "$MODE" == "full" ]]; then
  FILES_TO_ARCHIVE+=("moodle")
fi

if tar -czf "$BACKUP_DIR/$FILENAME" -C "$TMP_DIR" "${FILES_TO_ARCHIVE[@]}"; then
  print_cmsg "Backup complete: $BACKUP_DIR/$FILENAME" | tee -a "$LOG_FILE"
  rm -rf "$TMP_DIR"
else
  echo "Error: Failed to create backup. Temporary files remain in $TMP_DIR for analysis."
fi

# Renaming log file
mv "$LOG_FILE" "$LOG_DIR/moodle-backup/$FILENAME.log"