#!/bin/bash

# DJS Moodle Docker Install Script
# Author: JoSi
# Last Update: 2025-05-14
# Description: Sets up the Moodle Docker environment under /opt/moodle-docker.

# Variables
INSTALL_DIR="/opt/moodle-docker"
LOG_FILE="$INSTALL_DIR/logs/install.log"
SCRIPT_DIR="$(pwd)"

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
    echo "Performing system update..." | tee -a "$LOG_FILE"
    sudo apt-get update && sudo apt-get upgrade -y
    echo "System update completed." | tee -a "$LOG_FILE"
else
    echo "Skipping system update." | tee -a "$LOG_FILE"
fi


# Load environment variables
if [[ -f .env ]]; then
    source .env
else
    echo "No .env file found. Exiting." | tee -a "$LOG_FILE"
    exit 1
fi


# Creating required directories in $INSTALL_DIR
echo "Creating required directories in $INSTALL_DIR..." | tee -a "$LOG_FILE"
sudo mkdir -p "$INSTALL_DIR/moodle"
sudo mkdir -p "$INSTALL_DIR/moodledata"
sudo mkdir -p "$INSTALL_DIR/db_data"
sudo mkdir -p "$INSTALL_DIR/logs"


# Copies the Docker files (docker-compose.yml and Dockerfile) from the script directory to the installation directory
echo "Copying Docker files from $SCRIPT_DIR to $INSTALL_DIR..." | tee -a "$LOG_FILE"
sudo cp "$SCRIPT_DIR/Docker/docker-compose.yml" "$INSTALL_DIR/"
sudo cp "$SCRIPT_DIR/Docker/Dockerfile" "$INSTALL_DIR/"          


# Clone Moodle repository
echo "Cloning Moodle repository..." | tee -a "$LOG_FILE"
sudo git clone -b MOODLE_403_STABLE https://github.com/moodle/moodle.git "$INSTALL_DIR/moodle"


# Ask whether the existing MySQL database should be rebuilt or kept
read -p "Do you want to rebuild the MySQL database? (Y/n): " rebuild_db
rebuild_db=${rebuild_db:-Y}

if [[ "$rebuild_db" =~ ^[Yy]$ ]]; then
    # Create MySQL dump (adjust password or use .env)
    echo "Creating MySQL dump..." | tee -a "$LOG_FILE"
    mysqldump -u root -p"mysql-root-password" moodle > "$INSTALL_DIR/moodle.sql"
    
    # Stop and remove the old Moodle container if exists
    echo "Removing old Moodle container if it exists..." | tee -a "$LOG_FILE"
    docker stop moodle-db
    docker rm moodle-db

    # Rebuild the database container
    echo "Rebuilding MySQL container..." | tee -a "$LOG_FILE"
    docker-compose -f "$INSTALL_DIR/docker-compose.yml" up -d --build

    # Restore database dump inside the new container
    echo "Restoring database inside container..." | tee -a "$LOG_FILE"
    docker cp "$INSTALL_DIR/moodle.sql" moodle-db:/moodle.sql
    docker exec -i moodle-db sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" moodle < /moodle.sql'
    echo "Database rebuilt and restored." | tee -a "$LOG_FILE"
else
    echo "Skipping database rebuild. Keeping the existing database." | tee -a "$LOG_FILE"
fi


# Changing port configuration
# Backup und Anpassung von ports.conf
cp /etc/apache2/ports.conf /etc/apache2/ports.conf.bak
if ! grep -q '^Listen 8080' /etc/apache2/ports.conf; then
  echo 'Listen 8080' >> /etc/apache2/ports.conf
fi

# Backup und Anpassung der VirtualHost-Konfiguration
site_conf="/etc/apache2/sites-available/000-default.conf"
cp "$site_conf" "${site_conf}.bak"
sed -i "s/<VirtualHost \*:80>/<VirtualHost *:8080>/g" "$site_conf"

# Backup und Anpassung von config.php
moodle_cfg="/var/www/html/config.php"
cp "$moodle_cfg" "${moodle_cfg}.bak"
sed -i "s|\\$CFG->wwwroot\s*=.*|\\$CFG->wwwroot = 'http://localhost:8080';|g" "$moodle_cfg"

systemctl reload apache2

echo "Fertig: Apache lauscht nun auf 8080 und Moodle unter http://localhost:8080 erreichbar."


# Final message and Docker Compose instructions (English)
END_MSG="
+-----------------------------------------+
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
+-----------------------------------------+"

# Output the message to the console and append to the log file
echo "$END_MSG" | tee -a "$LOG_FILE"


