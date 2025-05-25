#!/bin/bash

# Moodle Docker backup script
# Author: dka
# Last Update: 2025-05-25
# Description: Moodle backup tool

clear

# Title
gum style --border normal --margin "1" --padding "1 2" --border-foreground 33 "Moodle Docker Backup Tool"

# Function: Prints the given text in bold on the console
print_cmsg() {
  if [[ "$1" == "-n" ]]; then
    shift
    echo -ne "\e[1m$*\e[0m"
  else
    echo -e "\e[1m$*\e[0m"
  fi
}

# Load environment variables from .env file in local directory
if [[ -f "./.env" ]]; then
    source "./.env"
    print_cmsg ".env file found and loaded from local directory."
else
    print_cmsg ".env file wasn't found in local directory. Exiting."
    exit 1
fi

# Load environment variables from .env file
source "./.env"

# Stop web service
print_cmsg "Stopping web server in container '$CONTAINER_MOODLE'..."
docker exec "$CONTAINER_MOODLE" service apache2 stop

# Get Moodle version from inside the container
MOODLE_VERSION=$(docker exec "$CONTAINER_MOODLE" \
  bash -c "sed -n \"s/.*\\\$release *= *'\([0-9.]*\).*/\1/p\" /var/www/html/version.php")

# Generate timestamp and filename
TIMESTAMP=$(date "+%Y%m%d-%H%M")
FILENAME="${MOODLE_VERSION}_${TIMESTAMP}_FULL.tar.gz"

print_cmsg "Creating database dump from container '$CONTAINER_DB'..."

# Dump the database
docker exec "$CONTAINER_DB" \
  bash -c "mysqldump -u$MYSQL_ROOT_USER -p$MYSQL_ROOT_PASSWORD $MYSQL_DATABASE" > "$BACKUP_DIR/db.sql"

print_cmsg "Copying Moodle files from container '$CONTAINER_MOODLE'..."

# Copy Moodle web files
docker cp "$CONTAINER_MOODLE":/var/www/html "$BACKUP_DIR/moodle"

print_cmsg "Creating archive..."

# Create compressed archive with both db.sql and web files
tar -czf "$BACKUP_DIR/$FILENAME" -C "$BACKUP_DIR" moodle db.sql

# Cleanup temporary files
rm -rf "$BACKUP_DIR/db.sql" "$BACKUP_DIR/moodle"

# Start web service again
print_cmsg "Starting web server in container '$CONTAINER_MOODLE'..."
docker exec "$CONTAINER_MOODLE" service apache2 start

print_cmsg "Backup complete: $BACKUP_DIR/$FILENAME"
