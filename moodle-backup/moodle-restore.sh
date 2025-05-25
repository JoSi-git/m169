#!/bin/bash

# Moodle Docker Restore Script
# Author: dka
# Last Update: 2025-05-21
# Description: Restores the last saved state in /opt/moodle-docker/tools/moodle-backup.

# Variables
INSTALL_DIR="/opt/moodle-docker"
BACKUP_DIR="$INSTALL_DIR/tools/moodle-backup"
RESTORE_DIR="$INSTALL_DIR/tools/moodle-restore"

# Read .env for MySQL Password
source "$INSTALL_DIR/.env"

# Find Newest Backup-File
LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*_FULL.tar.gz 2>/dev/null | head -n1)

if [[ -z "$LATEST_BACKUP" ]]; then
  echo "Kein Full-Backup gefunden in $BACKUP_DIR"
  exit 1
fi

# Prepare Restore
mkdir -p "$RESTORE_DIR"
rm -rf "$RESTORE_DIR"/*

# Unpack Backup and Copy Files back
tar -xzf "$LATEST_BACKUP" -C "$RESTORE_DIR"
cp -r "$RESTORE_DIR"/* /var/www/html/

# Restore DB
if [[ -f "$RESTORE_DIR/db.sql" ]]; then
  mysql -u root -p"$MYSQL_ROOT_PASSWORD" moodle < "$RESTORE_DIR/db.sql"
fi

# Cleanup
rm -rf "$RESTORE_DIR"/*
