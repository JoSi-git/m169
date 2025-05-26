#!/bin/bash

# Moodle Docker restore script
# Author: JoSi
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

# Load environment variables
source "./.env"

# Get list of backups sorted by modification time (most recent first), limited to 20
BACKUPS=($(ls -1t "$BACKUP_DIR"/*.tar.gz | head -n 20))

# Display available backups
gum style --border normal --padding "1 2" --border-foreground 33 <<EOF
0. Exit
$(printf '%s\n' "${BACKUPS[@]}" | nl -w1 -s'. ')
EOF

echo

# Prompt user for selection
read -p "Enter the number of the backup you want to restore (0 to exit): " SELECTION

# Handle exit option
if [[ "$SELECTION" == "0" ]]; then
  echo "Exiting..."
  exit 0
fi

# Validate input: must be a number and within valid range
if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || (( SELECTION < 1 || SELECTION > ${#BACKUPS[@]} )); then
  print_cmsg "Invalid selection. Exiting."
  exit 1
fi

# Get the selected backup file (arrays are zero-indexed)
BACKUP_FILE="${BACKUPS[$((SELECTION-1))]}"

print_cmsg "Restoring backup: $BACKUP_FILE"

# Stopping Apache2 webserver
print_cmsg "Stopping web server in container '$CONTAINER_MOODLE'..."
docker exec "$CONTAINER_MOODLE" service apache2 stop

# Create temporary restore directory
TMP_DIR=$(mktemp -d)

# Extract backup
tar -xzf "$BACKUP_FILE" -C "$TMP_DIR"

# Restore web files
print_cmsg "Copying web files back into container..."
docker cp "$TMP_DIR/moodle" "$CONTAINER_MOODLE":/var/www/html

# Set correct permissions
docker exec "$CONTAINER_MOODLE" chown -R www-data:www-data /var/www/html

# Restore database
print_cmsg "Importing SQL dump into database..."
cat "$TMP_DIR/db.sql" | docker exec -i "$CONTAINER_DB" \
  bash -c "mysql -u$MYSQL_ROOT_USER -p'$MYSQL_ROOT_PASSWORD' $MYSQL_DATABASE"

# Cleanup
rm -rf "$TMP_DIR"

print_cmsg "Starting web server in container '$CONTAINER_MOODLE'..."
docker exec "$CONTAINER_MOODLE" service apache2 start

print_cmsg "Restore complete."
