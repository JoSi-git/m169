#!/bin/bash

# Load environment variables
source "./.env"

# Container and database details
DB_USER="$MYSQL_USER"
DB_PASS="$MYSQL_ROOT_PASSWORD"
DB_NAME="$MYSQL_DATABASE"
MOODLE_CONTAINER="$CONTAINER_MOODLE"
DB_CONTAINER="$CONTAINER_DB"

# List available backups (most recent first)
echo "Available backups:"
ls -1t "$BACKUP_DIR"/*.tar.gz | head -n 20 | nl
echo

# Ask user for selection
read -p "Enter the number of the backup you want to restore: " SELECTION

# Resolve filename
BACKUP_FILE=$(ls -1t "$BACKUP_DIR"/*.tar.gz | head -n 20 | sed -n "${SELECTION}p")

# Validate selection
if [ -z "$BACKUP_FILE" ]; then
  echo "Invalid selection. Exiting."
  exit 1
fi

echo "Restoring backup: $BACKUP_FILE"


echo "Stopping web server in container '$MOODLE_CONTAINER'..."
docker exec "$MOODLE_CONTAINER" service apache2 stop

# Create temporary restore directory
TMP_DIR=$(mktemp -d)

# Extract backup
tar -xzf "$BACKUP_FILE" -C "$TMP_DIR"

# Restore web files
echo "Copying web files back into container..."
docker cp "$TMP_DIR/moodle" "$MOODLE_CONTAINER":/var/www/html

# Set correct permissions
docker exec "$MOODLE_CONTAINER" chown -R www-data:www-data /var/www/html

# Restore database
echo "Importing SQL dump into database..."
cat "$TMP_DIR/db.sql" | docker exec -i "$DB_CONTAINER" \
  bash -c "mysql -u$DB_USER -p$DB_PASS $DB_NAME"

# Cleanup
rm -rf "$TMP_DIR"

echo "Starting web server in container '$MOODLE_CONTAINER'..."
docker exec "$MOODLE_CONTAINER" service apache2 start

echo "Restore complete."
