#!/bin/bash

INSTALL_DIR="/opt/moodle-docker"
BACKUP_DIR="$INSTALL_DIR/tools/moodle-backup"
RESTORE_DIR="$INSTALL_DIR/tools/moodle-restore"

source "$INSTALL_DIR/.env"

LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*_FULL.tar.gz 2>/dev/null | head -n1)

if [[ -z "$LATEST_BACKUP" ]]; then
  echo "Kein Full-Backup gefunden in $BACKUP_DIR"
  exit 1
fi

mkdir -p "$RESTORE_DIR"
rm -rf "$RESTORE_DIR"/*

tar -xzf "$LATEST_BACKUP" -C "$RESTORE_DIR"

cp -r "$RESTORE_DIR"/* /var/www/html/

if [[ -f "$RESTORE_DIR/db.sql" ]]; then
  mysql -u root -p"$MYSQL_ROOT_PASSWORD" moodle < "$RESTORE_DIR/db.sql"
fi

rm -rf "$RESTORE_DIR"/*
