#!/bin/bash

# Moodle Docker Backup Script
# Author: dka
# Last Update: 2025-05-25
# Description: Moodle backup tool

# Load environment variables from .env file
source "./.env"

# Container and database details
DB_USER="$MYSQL_USER"
DB_PASS="$MYSQL_ROOT_PASSWORD"
DB_NAME="$MYSQL_DATABASE"
MOODLE_CONTAINER="$CONTAINER_MOODLE"
DB_CONTAINER="$CONTAINER_DB"

# Stop web service
echo "Stopping web server in container '$MOODLE_CONTAINER'..."
docker exec "$MOODLE_CONTAINER" service apache2 stop

# Get Moodle version from inside the container
MOODLE_VERSION=$(docker exec "$MOODLE_CONTAINER" \
  bash -c "sed -n \"s/.*\\\$release *= *'\([0-9.]*\).*/\1/p\" /var/www/html/version.php")

# Generate timestamp and filename
TIMESTAMP=$(date "+%Y%m%d-%H%M")
FILENAME="${MOODLE_VERSION}_${TIMESTAMP}_FULL.tar.gz"

echo "Creating database dump from container '$DB_CONTAINER'..."

# Dump the database
docker exec "$DB_CONTAINER" \
  bash -c "mysqldump -u$DB_USER -p$DB_PASS $DB_NAME" > "$BACKUP_DIR/db.sql"

echo "Copying Moodle files from container '$MOODLE_CONTAINER'..."

# Copy Moodle web files
docker cp "$MOODLE_CONTAINER":/var/www/html "$BACKUP_DIR/moodle"

echo "Creating archive..."

# Create compressed archive with both db.sql and web files
tar -czf "$BACKUP_DIR/$FILENAME" -C "$BACKUP_DIR" moodle db.sql

# Cleanup temporary files
rm -rf "$BACKUP_DIR/db.sql" "$BACKUP_DIR/moodle"

# Start web service again
echo "Starting web server in container '$MOODLE_CONTAINER'..."
docker exec "$MOODLE_CONTAINER" service apache2 start

echo "Backup complete: $BACKUP_DIR/$FILENAME"
