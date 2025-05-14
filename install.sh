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
echo "#############################################"
echo "#          Moodle Docker Installer          #"
echo "#############################################"
echo

# Ask if system updates should be performed
read -p "Do you want to perform system updates? (Y/n): " update_choice
update_choice=${update_choice:-Y}

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

# Perform system update if chosen
if [[ "$update_choice" =~ ^[Yy]$ ]]; then
    echo "Performing system update..." | tee -a "$LOG_FILE"
    sudo apt-get update && sudo apt-get upgrade -y
    echo "System update completed." | tee -a "$LOG_FILE"
else
    echo "Skipping system update." | tee -a "$LOG_FILE"
fi

# Clone Moodle repository (This is mandatory)
echo "Cloning Moodle repository..." | tee -a "$LOG_FILE"
sudo git clone -b MOODLE_403_STABLE https://github.com/moodle/moodle.git "$INSTALL_DIR/moodle"

# Copy current directory contents (Docker and other files) into /opt
echo "Copying Docker and other files from $SCRIPT_DIR to $INSTALL_DIR..." | tee -a "$LOG_FILE"
sudo cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"

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


