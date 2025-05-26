#!/bin/bash

# Moodle Docker status padge
# Author: josi
# Last Update: 2025-05-25
# Description: Simple terminal status padge made with gum

clear

# Load environment variables from .env
if [[ -f "./.env" ]]; then
  source "./.env"
  echo ".env file found and loaded from local directory."
else
  echo ".env file wasn't found in local directory. Exiting."
  exit 1
fi

# Config and color setup
WIDTH=100
BLUE="33"
LABEL_COLOR=$BLUE
VALUE_COLOR=$BLUE
HEADER_COLOR=$BLUE
OK_COLOR=$BLUE
ERR_COLOR=$BLUE

# Terminal width for centering
terminal_width=$(tput cols)
title_text="Welcome to the Moodle-Status Padge — all necessary services can be started and monitored with the following TUI"
padding=$(( (terminal_width - ${#title_text}) / 2 ))
centered_title=$(printf "%*s" $((padding + ${#title_text})) "$title_text")

# Warning text for first box
warning_text=$(gum style --foreground 196 --bold <<< "⚠ If you encounter any issues, please check the GitHub repository: https://github.com/JoSi-git/m169")

# Title box with warning
title_box=$(gum style --border normal --padding "1 3" --width $WIDTH \
  --foreground $BLUE --bold <<< "$centered_title"$'\n\n'"$warning_text")

# Docker Compose status check (no spinner)
if docker compose ls --format "{{.Service}}" &>/dev/null; then
  count=$(docker compose ls --format "{{.Service}}" | wc -l)
  if [ "$count" -gt 0 ]; then
    compose_icon="✔"
    compose_message="Docker Compose is running"
    compose_color=$OK_COLOR
  else
    compose_icon="✘"
    compose_message="Docker Compose is stopped"
    compose_color=$ERR_COLOR
  fi
else
  compose_icon="✘"
  compose_message="Docker Compose command not available"
  compose_color=$ERR_COLOR
fi

compose_status_box=$(gum style --border rounded --padding "1 3" --width $WIDTH \
  --border-foreground $compose_color <<< "$compose_icon   $compose_message")

# Docker container list
docker_status=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null)
docker_status="${docker_status:-Docker is not available}"

docker_box=$(gum style --border rounded --padding "1 3" --width $WIDTH \
  --border-foreground $BLUE <<< "$(gum style --foreground $HEADER_COLOR --bold <<< "Docker Container Status:")"$'\n'"$(gum style --foreground $VALUE_COLOR <<< "$docker_status")")

# Moodle dumps list (backups)
dumps_list=$(ls /opt/moodle-docker/dumps 2>/dev/null)
dumps_list="${dumps_list:-Directory /opt/moodle-docker/dumps not found}"

dumps_box=$(gum style --border rounded --padding "1 3" --width $WIDTH \
  --border-foreground $BLUE <<< "$(gum style --foreground $HEADER_COLOR --bold <<< "Moodle Backups:")"$'\n'"$(gum style --foreground $VALUE_COLOR <<< "$dumps_list")")

# Final output with all boxes stacked
output=$(printf "%s\n\n%s\n\n%s\n\n%s" "$title_box" "$compose_status_box" "$docker_box" "$dumps_box")
gum style --border rounded --padding "1 2" --width $((WIDTH + 6)) --border-foreground $BLUE <<< "$output"

# Interactive menu
choice=$(gum choose --header "What would you like to do?" \
  "[1] Open Documentation" \
  "[2] Start Moodle" \
  "[3] Stop Moodle" \
  "[4] Create Backup" \
  "[5] Restore Backup" \
  "[6] Run Moodle Cronjob" \
  "[7] Exit")

# Action handler


# Action handler
case "$choice" in
  "[1] Open Documentation")
    firefox "https://github.com/JoSi-git/m169/blob/main/README.md" >/dev/null 2>&1 &
    ;;
  "[2] Start Moodle")
    if gum confirm "Show logs?"; then
        cd "$INSTALL_DIR" && docker compose up && docker compose logs -f
    else
        cd "$INSTALL_DIR" && docker compose up -d
    fi
    ;;
  "[3] Stop Moodle")
    (cd "$INSTALL_DIR" && docker compose down)
    ;;
  "[4] Create Backup")
    sudo "$INSTALL_DIR/tools/moodle-backup/moodle-backup.sh"
    ;;
  "[5] Restore Backup")
    sudo "$INSTALL_DIR/tools/moodle-backup/moodle-restore.sh"
    ;;
  "[6] Run Moodle Cronjob")
    sudo "$INSTALL_DIR/tools/moodle-backup/moodle-cronjob.sh"
    ;;
  "[7] Exit")
    gum style --foreground "$VALUE_COLOR" <<< "Goodbye!"
    ;;
esac

