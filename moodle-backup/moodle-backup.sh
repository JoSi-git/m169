#!/bin/bash

# Moodle Docker backup script
# Author: JoSi
# Last Update: 2025-05-26
# Description: Moodle backup tool with interactive selection

clear

# Show title using Gum
gum style --border normal --margin "1" --padding "1 2" --border-foreground 33 "Moodle Docker Backup Tool"

# Function: Print bold messages to console
print_cmsg() {
  if [[ "$1" == "-n" ]]; then
    shift
    echo -ne "\e[1m$*\e[0m"
  else
    echo -e "\e[1m$*\e[0m"
  fi
}

# Load environment variables from local .env file
if [[ -f "./.env" ]]; then
    source "./.env"
    print_cmsg ".env file found and loaded from local directory."
else
    print_cmsg ".env file wasn't found in local directory. Exiting."
    exit 1
fi

# Display selection menu using Gum
CHOICE=$(gum choose "Exit" "Backup only database" "Backup only moodledata" "Backup both")

# Handle user choice
case "$CHOICE" in
  "Exit")
    print_cmsg "Exiting..."
    exit 0
    ;;
  "Backup only database")
    BACKUP_DB=true
    BACKUP_MOODLE=false
    ;;
  "Backup only moodledata")
    BACKUP_DB=false
    BACKUP_MOODLE=true
    ;;
  "Backup both")
    BACKUP_DB=true
    BACKUP_MOODLE=true
    ;;
  *)
    print_cmsg "Invalid choice. Exiting."
    exit 1
    ;;
esac

# Stop Apache inside Moodle container before backup
print_cmsg "Stopping web server in container '$CONTAINER_MOODLE'..."
docker exec "$CONTAINER_MOODLE" service apache2 stop

# Get Moodle version from inside container
MOODLE_VERSION=$(docker exec "$CONTAINER_MOODLE" \
  bash -c "sed -n \"s/.*\\\$release *= *'\([0-9.]*\).*/\1/p\" /var/www/html/version.php")

# Generate timestamp and backup filename
TIMESTAMP=$(date "+%Y%m%d-%H%M")
FILENAME="${MOODLE_VERSION}_${TIMESTAMP}_FULL.tar.gz"

# Prepare backup directories
mkdir -p "$BACKUP_DIR"
TMP_BACKUP_DIR=$(mktemp -d)

# Backup database if selected
if [[ "$BACKUP_DB" == true ]]; then
  print_cmsg "Creating database dump from container '$CONTAINER_DB'..."
  docker exec "$CONTAINER_DB" bash -c "mysqldump -u$MYSQL_ROOT_USER -p'$MYSQL_ROOT_PASSWORD' $MYSQL_DATABASE > /tmp/dump.sql"
  docker cp "$CONTAINER_DB":/tmp/dump.sql "$TMP_BACKUP_DIR/db.sql"
fi

# Backup Moodle files if selected
if [[ "$BACKUP_MOODLE" == true ]]; then
  print_cmsg "Copying Moodle files from container '$CONTAINER_MOODLE'..."
  docker cp "$CONTAINER_MOODLE":/var/www/html "$TMP_BACKUP_DIR/moodle"
fi

# Create tar.gz archive from temporary backup directory
print_cmsg "Creating archive..."
tar -czf "$BACKUP_DIR/$FILENAME" -C "$TMP_BACKUP_DIR" .

# Remove temporary files
rm -rf "$TMP_BACKUP_DIR"

# Restart Apache inside Moodle container
print_cmsg "Starting web server in container '$CONTAINER_MOODLE'..."
docker exec "$CONTAINER_MOODLE" service apache2 start

# Final confirmation
print_cmsg "Backup complete: $BACKUP_DIR/$FILENAME"
