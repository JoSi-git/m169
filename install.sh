#!/bin/bash

# DJS Moodle Docker Install Script
# Author: JoSi
# Last Update: 2025-05-14
# Description: Sets up the Moodle Docker environment under /opt/moodle-docker.

# Variables
INSTALL_DIR="/opt/moodle-docker"
LOG_FILE="$INSTALL_DIR/logs/install.log"
SCRIPT_DIR="$(pwd)"
ENV_FILE="$SCRIPT_DIR/Docker/.env"

# Display title
clear
cat <<'EOF'

----------------------------------------------------------------------------------------------------------
  ___  ___    _   __  __              _ _       ___          _             _         _        _ _         
 |   \/ __|_ | | |  \/  |___  ___  __| | |___  |   \ ___  __| |_____ _ _  (_)_ _  __| |_ __ _| | |___ _ _ 
 | |) \__ \ || | | |\/| / _ \/ _ \/ _` | / -_) | |) / _ \/ _| / / -_) '_| | | ' \(_-<  _/ _` | | / -_) '_|
 |___/|___/\__/  |_|  |_\___/\___/\__,_|_\___| |___/\___/\__|_\_\___|_|   |_|_||_/__/\__\__,_|_|_\___|_|

----------------------------------------------------------------------------------------------------------

EOF

# Ask if system updates should be performed
read -p "Do you want to perform system updates? (Y/n): " update_choice
update_choice=${update_choice:-Y}

# Perform system update if chosen
if [[ "$update_choice" =~ ^[Yy]$ ]]; then
    echo -e "\033[1mPerforming system update...\033[0m" | tee -a "$LOG_FILE"
    sudo apt-get update && sudo apt-get upgrade -y
    echo -e "\033[1mSystem update completed.\033[0m" | tee -a "$LOG_FILE"
else
    echo -e "\033[1mSkipping system update.\033[0m" | tee -a "$LOG_FILE"
fi

# Load environment variables from .env file
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
    echo -e "\033[1m.env file found and loaded.\033[0m" | tee -a "$LOG_FILE"
else
    echo -e "\033[1mNo .env file found in $SCRIPT_DIR/Docker. Exiting.\033[0m" | tee -a "$LOG_FILE"
    exit 1
fi

# Creating required directories in $INSTALL_DIR
echo -e "\033[1mCreating required directories in $INSTALL_DIR...\033[0m" | tee -a "$LOG_FILE"
sudo mkdir -p "$INSTALL_DIR/moodle"
sudo mkdir -p "$INSTALL_DIR/moodledata"
sudo mkdir -p "$INSTALL_DIR/db_data"
sudo mkdir -p "$INSTALL_DIR/logs"
sudo mkdir -p "$INSTALL_DIR/logs/moodle"
sudo mkdir -p "$INSTALL_DIR/logs/apache"
sudo mkdir -p "$INSTALL_DIR/logs/mariadb"

# Copy Docker files
echo -e "\033[1mCopying Docker files from $SCRIPT_DIR/Docker to $INSTALL_DIR...\033[0m" | tee -a "$LOG_FILE"
sudo cp "$SCRIPT_DIR/Docker/docker-compose.yml" "$INSTALL_DIR/"
sudo cp "$SCRIPT_DIR/Docker/Dockerfile" "$INSTALL_DIR/"
sudo cp "$SCRIPT_DIR/Docker/.env" "$INSTALL_DIR/"

# Clone Moodle repository
echo -e "\033[1mCloning Moodle repository...\033[0m" | tee -a "$LOG_FILE"
sudo git clone -b MOODLE_403_STABLE https://github.com/moodle/moodle.git "$INSTALL_DIR/moodle"

# Changing port configuration
echo -e "\033[1mAdjusting Apache ports and Moodle config...\033[0m" | tee -a "$LOG_FILE"
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

sudo systemctl reload apache2


# Final message and Docker Compose instructions (English)
END_MSG="
\033[1m+-----------------------------------------+
|     Installation Complete               |
|-----------------------------------------|
| Moodle Docker setup complete!           |
|                                         |
| 1. Go to directory:                     |
|    cd /opt/moodle-docker                |
| 2. Start containers:                    |
|    docker-compose up -d                 |
| 3. Check status:                        |
|    docker-compose ps                    |
| 4. Access Moodle:                       |
|    http://localhost:80                  |
| 5. Stop containers:                     |
|    docker-compose down                  |
|                                         |
| Note: Old infrastructure remains        |
| accessible under http://localhost:8080  |
| Installation log at '$LOG_FILE'.        |
+-----------------------------------------+\033[0m"

# Output the message to the console and append to the log file
echo -e "$END_MSG" | tee -a "$LOG_FILE"
