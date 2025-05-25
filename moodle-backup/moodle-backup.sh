#!/bin/bash

#Variablen
INSTALL_DIR="/opt/moodle-docker"
BACKUP_DIR="$INSTALL_DIR/tools/moodle-backup"
MOODLE_VERSION=$(sed -n "s/.*\$release *= *'\([0-9.]*\).*/\1/p" /var/www/html/version.php)
TIMESTAMP=$(date "+%Y%m%d-%H%M")

#Entscheidung Full oder Incremental
MODE=""

while getopts "fi" opt; do
  case $opt in
    f) MODE="FULL" ;;
    i) MODE="INCREMENTAL" ;;
    *) exit 1 ;;
  esac
done

# Prüfen ob Modus gesetzt wurde
if [[ -z "$MODE" ]]; then
  exit 1
fi

FILENAME="${MOODLE_VERSION}_${TIMESTAMP}_${MODE}.tar.gz"

#Datenbank Dump
mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" moodle > "$BACKUP_DIR/db.sql"

#Packen ins Archiv
tar -czf "$BACKUP_DIR/$FILENAME" -C /var/www/html . -C "$BACKUP_DIR" db.sql

#Aufräumen
rm "$BACKUP_DIR/db.sql"
