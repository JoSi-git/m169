#!/bin/bash

# Moodle Docker Restore Script
# Author: JoSi
# Last Update: 2025-05-26

# Show title
gum style --border normal --margin "1" --padding "1 2" --border-foreground 33 "Moodle Docker Restore Tool"

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

# Get list of available backup files (limit to 20 most recent)
BACKUPS=($(ls -1t "$BACKUP_DIR"/*.tar.gz | head -n 20))

# Display available backups in a styled list
gum style --border normal --padding "1 2" --border-foreground 33 <<EOF
0. Exit
$(printf '%s\n' "${BACKUPS[@]}" | nl -w1 -s'. ')
EOF

echo

# Prompt for user input
read -p "Enter the number of the backup you want to restore (0 to exit): " SELECTION

# Handle exit
if [[ "$SELECTION" == "0" ]]; then
  echo "Exiting..."
  exit 0
fi

# Validate selection
if ! [[ "$SELECTION" =~ ^[0-9]+$ ]] || (( SELECTION < 1 || SELECTION > ${#BACKUPS[@]} )); then
  print_cmsg "Invalid selection. Exiting."
  exit 1
fi

# Get selected backup
BACKUP_FILE="${BACKUPS[$((SELECTION-1))]}"
print_cmsg "Selected backup: $BACKUP_FILE"

# Stop Apache in Moodle container
print_cmsg "Stopping web server in container '$CONTAINER_MOODLE'..."
docker exec "$CONTAINER_MOODLE" service apache2 stop

# Create temporary restore directory
TMP_DIR=$(mktemp -d)

# Extract backup contents
tar -xzf "$BACKUP_FILE" -C "$TMP_DIR"

# Restore Moodle files (if present)
if [[ -d "$TMP_DIR/moodle" ]]; then
  print_cmsg "Restoring Moodle files to container '$CONTAINER_MOODLE'..."
  docker cp "$TMP_DIR/moodle" "$CONTAINER_MOODLE":/var/www/html
  docker exec "$CONTAINER_MOODLE" chown -R www-data:www-data /var/www/html
else
  print_cmsg "No Moodle web files found in backup. Skipping file restore."
fi

# Restore database dump (if present)
if [[ -f "$TMP_DIR/db.sql" ]]; then
  print_cmsg "Restoring database to container '$CONTAINER_DB'..."
  cat "$TMP_DIR/db.sql" | docker exec -i "$CONTAINER_DB" \
    bash -c "mysql -u$MYSQL_ROOT_USER -p'$MYSQL_ROOT_PASSWORD' $MYSQL_DATABASE"
else
  print_cmsg "No database dump found in backup. Skipping database restore."
fi

# Cleanup
rm -rf "$TMP_DIR"

# Start Apache again
print_cmsg "Starting web server in container '$CONTAINER_MOODLE'..."
docker exec "$CONTAINER_MOODLE" service apache2 start

# Done
print_cmsg "Restore complete."
