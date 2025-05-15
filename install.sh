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
SHELL_RC="$HOME/.bashrc"
Version="V1.0"

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

# moodle migration
# Mysql Dump
mysqldump -u root -p$MYSQL_ROOT_PASSWORD > /opt/moodle-docker/moodle_backup.sql
# copy moodledata
cp -r /var/www/moodledata /opt/moodle-docker


# Add aliases to ~/.bashrc (if not already present)
if ! grep -q "alias moodleup=" "$SHELL_RC"; then
    {
        echo ""
        echo "# Moodle Docker aliases"
        echo "alias moodleup='cd /opt/moodle-docker && docker-compose up -d && docker-compose ps && xdg-open http://localhost'"
        echo "alias moodledown='cd /opt/moodle-docker && docker-compose down'"
        echo "alias moodlebackup='echo \"[WIP] moodlebackup: This function is still under development. For details, see: https://github.com/JoSi-git/m169\"'"
    } >> "$SHELL_RC"
    echo "Aliases 'moodleup', 'moodledown', and 'moodlebackup' added to $SHELL_RC" | tee -a "$LOG_FILE"
else
    echo "Aliases already exist in $SHELL_RC – skipping addition." | tee -a "$LOG_FILE"
fi

# Note for activation
echo "Run 'source ~/.bashrc' or restart your terminal to activate the new aliases." | tee -a "$LOG_FILE"

# Final message and Docker Compose instructions
cat <<'EOF'
+---------------------------------------------------------------------------------------------------+
|                             			Installation Complete!                     					|
|---------------------------------------------------------------------------------------------------|
| Moodle Docker setup complete!                                                  					|
|                                                                                					|
| ➤ Start Moodle:                                                               					|
|   cd /opt/moodle-docker && docker-compose up -d                                					|
|   → Status: docker-compose ps                                                  					|
|   → Access: http://localhost:80                           			■■     		.               |
|                                                                 ■■ ■■ ■■       	 ==        		|
| ➤ Stop:                                    	   			   ■■ ■■ ■■ ■■ ■■ 	     ===      		|
|   docker-compose down                                   	/"""""""""""""""""""\____/ ===          |
|                                                 	~~~ ~~ {                          /~ === ~~ ~~~ |
| ➤ You can also use aliases for convenience:         		\						 /		-     	|
|   moodleup     → Starts & opens Moodle              		 \_______ O           __/				|
|   moodledown   → Stops containers                    				\___________/					|
|                                                                                					|
| ➤ Start backup:                                       	DJS Moodle Docker Install Script  		|
|   moodlebackup                                                      	$Version        			|
|   Guide: https://github.com/JoSi-git/m169/readme.md                            					|
|                                                                                					|
| ➤ Legacy system: http://localhost:8080                                         					|
|																									|
| ➤ Log file: $LOG_FILE                                                          					
+---------------------------------------------------------------------------------------------------+"
EOF | tee -a "$LOG_FILE"
