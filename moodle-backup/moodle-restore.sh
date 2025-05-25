#!/bin/bash

INSTALL_DIR="/opt/moodle-docker"
RESTORE_DIR="$INSTALL_DIR/tools/moodle-restore"
BACKUP_DIR="$INSTALL_DIR/tools/moodle-backup"

MODE=""

while getopts "fi" opt; do
  case $opt in
    f) MODE="FULL" ;;
    i) MODE="INCREMENTAL" ;;
    *) exit 1 ;;
  esac
done

if [[ -z "$MODE" ]]; then
  echo "Bitte gib -f (Full) oder -i (Incremental) an"
  exit 1
fi

LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*_${MODE}.tar.gz 2>/dev/null | head -n1)

if [[ -z "$LATEST_BACKUP" ]]; then
  echo "Kein ${MODE}-Backup gefunden."
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
