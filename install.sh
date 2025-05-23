#!/bin/bash

# DJS Moodle Docker Install Script
# Author: JoSi
# Last Update: 2025-05-21
# Description: Sets up the Moodle Docker environment under /opt/moodle-docker.

# Variables
INSTALL_DIR="/opt/moodle-docker"
LOG_FILE="$INSTALL_DIR/logs/install.log"
SCRIPT_DIR="$(pwd)"
ENV_FILE="$SCRIPT_DIR/docker/.env"
SHELL_RC="/home/$SUDO_USER/.bashrc"
TIMESTAMP=$(date "+%Y.%m.%d-%H.%M")
MOODLE_VERSION=$(sed -n "s/.*\$release *= *'\([0-9.]*\).*/\1/p" /var/www/html/version.php)
BACKUP_DIR="${INSTALL_DIR}/dumps/${MOODLE_VERSION}-${TIMESTAMP}"
VER="V1.0"

# Function: Prints the given text in bold on the console
print_cmsg() {
  if [[ "$1" == "-n" ]]; then
    shift
    echo -ne "\e[1m$*\e[0m"
  else
    echo -e "\e[1m$*\e[0m"
  fi
}

# Creating install log directory
mkdir -p "$INSTALL_DIR/logs"

# Display title
clear

cat <<EOF | tee -a "$LOG_FILE"
$(printf '\033[38;5;33m')----------------------------------------------------------------------------------------------------------
  ___  ___    _   __  __              _ _       ___          _             _         _        _ _
 |   \/ __|_ | | |  \/  |___  ___  __| | |___  |   \ ___  __| |_____ _ _  (_)_ _  __| |_ __ _| | |___ _ _
 | |) \__ \ || | | |\/| / _ \/ _ \/ _\` | / -_) | |) / _ \/ _| / / -_) '_| | | ' \(_-<  _/ _\` | | / -_) '_|
 |___/|___/\__/  |_|  |_\___/\___/\__,_|_\___| |___/\___/\__|_\_\___|_|   |_|_||_/__/\__\__,_|_|_\___|_|
----------------------------------------------------------------------------------------------------------
$(printf '\033[0m')
EOF


# Check if the script is running as root
if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run with sudo or as root." >&2
  exec sudo "$0" "$@"
  exit 1
fi

# Ask if system updates should be performed
print_cmsg -n "Do you want to perform system updates? (Y/n):"
read update_choice
update_choice=${update_choice:-Y}


# Perform system update if chosen
if [[ "$update_choice" =~ ^[Yy]$ ]]; then
    print_cmsg "Performing system update..." | tee -a "$LOG_FILE"
    sudo apt update -y && sudo apt upgrade -y
    print_cmsg "System update completed." | tee -a "$LOG_FILE"
else
    print_cmsg "Skipping system update." | tee -a "$LOG_FILE"
fi

# Installing gum
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update && sudo apt install gum

# Load environment variables from .env file
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
    print_cmsg ".env file found and loaded." | tee -a "$LOG_FILE"
else
    print_cmsg ".env file wasn't found in $SCRIPT_DIR/docker. Exiting." | tee -a "$LOG_FILE"
    exit 1
fi

# Creating required directories in $INSTALL_DIR
print_cmsg "Creating required directories in $INSTALL_DIR..." | tee -a "$LOG_FILE"
mkdir -p "$INSTALL_DIR/moodle"
mkdir -p "$INSTALL_DIR/moodledata"
mkdir -p "$INSTALL_DIR/db_data"
mkdir -p "$INSTALL_DIR/tools"
mkdir -p "$INSTALL_DIR/tools/moodle-backup"
mkdir -p "$INSTALL_DIR/tools/moodle-migration"
mkdir -p "$INSTALL_DIR/dumps"
mkdir -p "$INSTALL_DIR/logs/moodle"
mkdir -p "$INSTALL_DIR/logs/apache"
mkdir -p "$INSTALL_DIR/logs/mariadb"

# Copy Docker files
print_cmsg "Copying files from $SCRIPT_DIR/docker to $INSTALL_DIR..." | tee -a "$LOG_FILE"
cp -r "$SCRIPT_DIR/docker/"* "$INSTALL_DIR/"
cp -r "$SCRIPT_DIR/moodle-backup" "$INSTALL_DIR/tools"
cp -r "$SCRIPT_DIR/moodle-migration" "$INSTALL_DIR/tools"

# Clone Moodle repository
print_cmsg "Cloning Moodle repository..." | tee -a "$LOG_FILE"
git clone -b MOODLE_403_STABLE https://github.com/moodle/moodle.git "$INSTALL_DIR/moodle"

# Changing port configuration
print_cmsg "Adjusting Apache ports and Moodle config..." | tee -a "$LOG_FILE"
sed -i 's/^\s*Listen\s\+80$/Listen 8080/' /etc/apache2/ports.conf

site_conf="/etc/apache2/sites-available/000-default.conf"
cp "$site_conf" "${site_conf}.bak"
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:8080>/g" "$site_conf"

moodle_cfg="/var/www/html/config.php"
cp "$moodle_cfg" "${moodle_cfg}.bak"
sed -i "s|\\$CFG->wwwroot\s*=.*|\\$CFG->wwwroot = 'http://localhost:8080';|g" "$moodle_cfg"

# Adding warning banner into old instance
f="/var/www/html/theme/boost/templates/columns2.mustache"
cp "$f" "$f.bak"
awk '/{{> theme_boost\/navbar }}/ {print; print "<div style=\"background-color: #f8d7da; color: #721c24; text-align: center; padding: 20px; font-weight: bold; font-size: 24px;\"><br>Diese Moodle-Seite ist <strong>veraltet</strong> und wird <strong>nicht mehr gewartet</strong>. Bitte verwende stattdessen <a href=\"http://localhost:80\" style=\"color: #721c24; font-weight: bold; text-decoration: none;\">http://localhost:80</a></div>"; next}1' "$f.bak" > "$f"

systemctl reload apache2

# Moodle migration

# Create the backup directory
mkdir -p "$BACKUP_DIR"

# Perform a MySQL dump of the Moodle database
mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" > "${BACKUP_DIR}/moodle_dump.sql"

# Copy the moodledata directory to the backup location
cp -r /var/www/moodledata "${INSTALL_DIR}/moodledata"

# Add aliases to ~/.bashrc (if not already present)
if ! grep -qE "^alias moodle-up=" "$SHELL_RC"; then
    {
        echo ""
        echo "# Moodle Docker aliases"
        echo "alias moodle-up='(cd \"$INSTALL_DIR\" && docker compose up -d && docker compose ps && xdg-open http://localhost)'"
        echo "alias moodle-down='(cd \"$INSTALL_DIR\" && docker compose down)'"
        echo "alias moodle-backup='(\"$INSTALL_DIR\"/tools/moodle-backup/moodle-backup.sh)'"
        echo "alias moodle-restore='(\"$INSTALL_DIR\"/tools/moodle-backup/moodle-restore.sh)'"
    } >> "$SHELL_RC"
     print_cmsg "Aliases 'moodle-up', 'moodle-down', 'moodle-backup', and 'moodle-restore added to $SHELL_RC" | tee -a "$LOG_FILE"
else
    print_cmsg "Aliases already exist in $SHELL_RC - skipping addition." | tee -a "$LOG_FILE"
fi


# Note on activation
print_cmsg "Run 'source ~/.bashrc' or restart your terminal to activate the new aliases." | tee -a "$LOG_FILE"

# Final message and Docker Compose instructions
gum style --border normal --margin "1" --padding "1 2" --border-foreground 33 << EOF | tee -a "$LOG_FILE"
═════════════════════════════════════════════════════════════════════════════════════════════════
                                Moodle Docker setup complete!
═════════════════════════════════════════════════════════════════════════════════════════════════

 => Start Moodle:
   cd /opt/moodle-docker && docker compose up -d
   -> Status: docker compose ps
   -> Access: http://localhost:80                                      ■■          .
                                                                 ■■ ■■ ■■           ==
 => Stop:                                                     ■■ ■■ ■■ ■■ ■■         ===
   docker compose down                                     /"""""""""""""""""""\____/ ===
                                                 ~ ~~~ ~~ {                          /~ === ~~ ~~~
 => You can also use aliases for convenience:              \                        /      -
   moodleup     -> Starts & opens Moodle                    \_______ O           __/
   moodledown   -> Stops containers                                 \___________/

 => Start backup:                                          DJS Moodle Docker Install Script
   moodlebackup                                                      	$VER
   Guide: https://github.com/JoSi-git/m169/readme.md

 => Legacy system: http://localhost:8080

 => Log file: $LOG_FILE
EOF

exit