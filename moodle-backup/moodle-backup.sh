#!/bin/bash

# Moodle Docker Backup Script
# Author: dka
# Last Update: 2025-05-25
# Description: Creates a Full Backup of the Database in /opt/moodle-docker/tools/moodle-backup.

# Moodle Full Backup Script
INSTALL_DIR="/opt/moodle-docker"
BACKUP_DIR="$INSTALL_DIR/tools/moodle-backup"
MOODLE_VERSION=$(sed -n "s/.*\$release *= *'\([0-9.]*\).*/\1/p" /var/www/html/version.php)
TIMESTAMP=$(date "+%Y%m%d-%H%M")
FILENAME="${MOODLE_VERSION}_${TIMESTAMP}_FULL.tar.gz"

# Read .env for MySQL Password
source "$INSTALL_DIR/.env"

mkdir -p "$BACKUP_DIR"

# Create DB Dump
mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" moodle > "$BACKUP_DIR/db.sql"

# Bundling
tar -czf "$BACKUP_DIR/$FILENAME" -C /var/www/html . -C "$BACKUP_DIR" db.sql

# Remove Temp Dump-File
rm "$BACKUP_DIR/db.sql"
