#!/bin/bash

# Moodle Docker restore script
# Author: dka
# Last Update: 2025-05-25
# Description: Moodle restore tool

# Title
gum style --border normal --margin "1" --padding "1 2" --border-foreground 33 "Moodle Docker restore Tool"

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

# Check if the script is running as root
if [[ "$EUID" -ne 0 ]]; then
  print_cmsg "This script must be run with sudo or as root." >&2
  exec sudo "$0" "$@"
  exit 1
fi

# Load environment variables
set -o allexport
source "./.env"
set +0 allexport
# Container and database details
DB_USER="$MYSQL_ROOT_USER"
DB_PASS="$MYSQL_ROOT_PASSWORD"
DB_NAME="$MYSQL_DATABASE"
MOODLE_CONTAINER="$CONTAINER_MOODLE"
DB_CONTAINER="$CONTAINER_DB"

# List available backups (most recent first)
gum style --border normal --padding "1 2" --border-foreground 33 <<EOF
$(ls -1t "$BACKUP_DIR"/*.tar.gz | head -n 20 | nl)
EOF

echo

# Ask user for selection
read -p "Enter the number of the backup you want to restore: " SELECTION

# Resolve filename
BACKUP_FILE=$(ls -1t "$BACKUP_DIR"/*.tar.gz | head -n 20 | sed -n "${SELECTION}p")

# Validate selection
if [ -z "$BACKUP_FILE" ]; then
  print_cmsg "Invalid selection. Exiting."
  exit 1
fi

print_cmsg "Restoring backup: $BACKUP_FILE"


print_cmsg "Stopping web server in container '$MOODLE_CONTAINER'..."
docker exec "$MOODLE_CONTAINER" service apache2 stop

# Create temporary restore directory
TMP_DIR=$(mktemp -d)

# Extract backup
tar -xzf "$BACKUP_FILE" -C "$TMP_DIR"

# Restore web files
print_cmsg "Copying web files back into container..."
docker cp "$TMP_DIR/moodle" "$MOODLE_CONTAINER":/var/www/html

# Set correct permissions
docker exec "$MOODLE_CONTAINER" chown -R www-data:www-data /var/www/html

# Restore database
print_cmsg "Importing SQL dump into database..."
cat "$TMP_DIR/db.sql" | docker exec -i "$DB_CONTAINER" \
  bash -c "mysql -u$DB_USER -p$DB_PASS $DB_NAME"

# Cleanup
rm -rf "$TMP_DIR"

print_cmsg "Starting web server in container '$MOODLE_CONTAINER'..."
docker exec "$MOODLE_CONTAINER" service apache2 start

print_cmsg "Restore complete."
