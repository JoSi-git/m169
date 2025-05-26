#!/bin/bash

# Moodle Docker status padge
# Author: josi
# Last Update: 2025-05-26
# Description: Simple terminal status padge made with gum

# Load environment variables from .env
if [[ -f "./.env" ]]; then
  source "./.env"
  echo ".env file found and loaded from local directory."
else
  echo ".env file wasn't found in local directory. Exiting."
  exit 1
fi

clear

# Config
WIDTH=100
BLUE="33"

# Title box content
title_box_content=$(cat <<'EOF'
 __  __              _ _       ___          _             ___ _        _           
|  \/  |___  ___  __| | |___  |   \ ___  __| |_____ _ _  / __| |_ __ _| |_ _  _ ___
| |\/| / _ \/ _ \/ _` | / -_) | |) / _ \/ _| / / -_) '_| \__ \  _/ _` |  _| || (_-<
|_|  |_\___/\___/\__,_|_\___| |___/\___/\__|_\_\___|_|   |___/\__\__,_|\__|\_,_/__/

                Welcome to the Moodle-Status Padge — all necessary services
                        can be started and monitored with the TUI

                If you encounter any issues, please check the GitHub repository:
                        https://github.com/JoSi-git/m169
EOF
)

title_box=$(gum style --border rounded --padding "1 3" --width $WIDTH <<< "$title_box_content")

# Docker Compose status check
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  running_projects=$(docker compose ls | tail -n +2 | awk '{print $2}' | grep -c "running")

  if [ "$running_projects" -gt 0 ]; then
    compose_icon="✔"
    compose_message="Docker Compose is running"
  else
    compose_icon="✘"
    compose_message="No Docker Compose project is running"
  fi
else
  compose_icon="✘"
  compose_message="Docker Compose command not available"
fi

compose_status_box=$(gum style --border rounded --padding "1 3" --width $WIDTH \
  --border-foreground $BLUE <<< "$compose_icon   $compose_message")

# Docker container list
docker_status=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
docker_status="${docker_status:-Docker is not available}"

docker_box=$(gum style --border rounded --padding "1 3" --width $WIDTH <<< \
"$(gum style --bold <<< "Docker Container Status:")"$'\n'"$docker_status")

# Moodle dumps list (backups)
dumps_list=$(ls /opt/moodle-docker/dumps 2>/dev/null)
dumps_list="${dumps_list:-Directory /opt/moodle-docker/dumps not found}"

dumps_box=$(gum style --border rounded --padding "1 3" --width $WIDTH <<< \
"$(gum style --bold <<< "Moodle Backups:")"$'\n'"$dumps_list")

# Final output
output=$(printf "%s\n\n%s\n\n%s\n\n%s" "$title_box" "$compose_status_box" "$docker_box" "$dumps_box")
gum style --border rounded --padding "1 2" --width $((WIDTH + 6)) <<< "$output"

# Interactive menu
choice=$(gum choose --header "What would you like to do?" \
  "[1] Start Moodle" \
  "[2] Stop Moodle" \
  "[3] Create Backup" \
  "[4] Restore Backup" \
  "[5] Run Moodle Cronjob" \
  "[6] Exit")

# Action handler
case "$choice" in
  "[1] Start Moodle")
    if gum confirm "Show logs?"; then
      cd "$INSTALL_DIR" && docker compose up && docker compose logs -f
    else
      cd "$INSTALL_DIR" && docker compose up -d
    fi
    ;;
  "[2] Stop Moodle")
    (cd "$INSTALL_DIR" && docker compose down)
    ;;
  "[3] Create Backup")
    sudo "$INSTALL_DIR/tools/moodle-backup/moodle-backup.sh"
    ;;
  "[4] Restore Backup")
    sudo "$INSTALL_DIR/tools/moodle-backup/moodle-restore.sh"
    ;;
  "[5] Run Moodle Cronjob")
    sudo "$INSTALL_DIR/tools/moodle-backup/moodle-cronjob.sh"
    ;;
  "[6] Exit")
    echo "Goodbye!"
    ;;
esac
