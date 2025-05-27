#!/bin/bash

# Moodle Backup Scheduler with Gum UI
# Author: JoSi (style matched)
# Last Update: 2025-05-27
# Description: Interactive schedule manager using gum to configure backup cronjobs.

SCHEDULE_FILE="./backup-schedule.json"
CRON_COMMENT="# Moodle Docker Backup Scheduler"
BACKUP_CMD="/usr/local/bin/moodle-backup"  # Adjust path to your backup script
CRON_TMP=$(mktemp)

print_cmsg() {
  if [[ "$1" == "-n" ]]; then
    shift
    echo -ne "\e[1m$*\e[0m"
  else
    echo -e "\e[1m$*\e[0m"
  fi
}

# Map weekday names to cron weekday numbers
declare -A DAY_TO_CRON=(
  [Sunday]=0
  [Monday]=1
  [Tuesday]=2
  [Wednesday]=3
  [Thursday]=4
  [Friday]=5
  [Saturday]=6
)

days_to_cron_wday() {
  local days=("$@")
  local cron_days=()
  for d in "${days[@]}"; do
    cron_days+=("${DAY_TO_CRON[$d]}")
  done
  IFS=','; echo "${cron_days[*]}"
}

# Ensure schedule file exists
if [[ ! -f "$SCHEDULE_FILE" ]]; then
  echo "[]" > "$SCHEDULE_FILE"
fi

# Load schedule JSON into bash array
load_schedule() {
  mapfile -t schedule < <(jq -c '.[]' "$SCHEDULE_FILE")
}

# Show current schedule entries in a nice table
show_schedule() {
  if [[ ! -s "$SCHEDULE_FILE" ]]; then
    print_cmsg "No backup schedules defined yet."
    return
  fi

  echo "Current backup schedules:"
  echo "-------------------------"
  printf "%-3s | %-10s | %-20s | %-5s\n" "No" "Mode" "Days" "Time"
  echo "--------------------------------------------"
  local i=1
  for item in "${schedule[@]}"; do
    local mode=$(echo "$item" | jq -r '.mode')
    local days=$(echo "$item" | jq -r '.days | join(", ")')
    local time=$(echo "$item" | jq -r '.time')
    printf "%-3d | %-10s | %-20s | %-5s\n" "$i" "$mode" "$days" "$time"
    ((i++))
  done
  echo
}

# Add new schedule entry
add_schedule() {
  # Choose mode
  local modes=("--full" "--db-only" "--moodle-only")
  local mode
  mode=$(gum choose "${modes[@]}")

  # Choose days (multi-select)
  local all_days=(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)
  local days
  days=$(gum choose --no-limit "${all_days[@]}")

  # Input time HH:MM with validation
  local time
  while true; do
    time=$(gum input --prompt="Enter backup time (HH:MM 24h format):")
    if [[ "$time" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
      break
    else
      gum style --foreground=red --bold "Invalid time format. Please enter HH:MM (24h)."
    fi
  done

  # Build JSON object for new entry
  local json_days
  json_days=$(printf '%s\n' $days | jq -R . | jq -s .)

  # Append new entry to existing schedule
  jq --arg mode "$mode" --argjson days "$json_days" --arg time "$time" \
    '. += [{"mode": $mode, "days": $days, "time": $time}]' "$SCHEDULE_FILE" > "${SCHEDULE_FILE}.tmp" && mv "${SCHEDULE_FILE}.tmp" "$SCHEDULE_FILE"

  print_cmsg "New schedule added: Mode=$mode, Days=$days, Time=$time"
}

# Remove schedule entry by number
remove_schedule() {
  local count=${#schedule[@]}
  if (( count == 0 )); then
    print_cmsg "No schedules to remove."
    return
  fi

  # Prepare options for gum choose with line numbers + summary
  local options=()
  local i=1
  for item in "${schedule[@]}"; do
    local mode=$(echo "$item" | jq -r '.mode')
    local days=$(echo "$item" | jq -r '.days | join(", ")')
    local time=$(echo "$item" | jq -r '.time')
    options+=("$i) Mode=$mode, Days=$days, Time=$time")
    ((i++))
  done

  local choice
  choice=$(gum choose "${options[@]}")
  if [[ -z "$choice" ]]; then
    print_cmsg "No selection made."
    return
  fi

  # Extract number from selection
  local num=${choice%%)*}
  num=$((num))

  # Remove selected entry from schedule array
  jq "del(.[$((num-1))])" "$SCHEDULE_FILE" > "${SCHEDULE_FILE}.tmp" && mv "${SCHEDULE_FILE}.tmp" "$SCHEDULE_FILE"
  print_cmsg "Removed schedule entry #$num."
}

# Install cron jobs from schedule
install_cronjobs() {
  load_schedule
  print_cmsg "Installing cron jobs from schedule...\n"

  # Get current user crontab without old Moodle lines
  crontab -l 2>/dev/null | grep -v "$CRON_COMMENT" > "$CRON_TMP"

  for item in "${schedule[@]}"; do
    mode=$(echo "$item" | jq -r '.mode')
    days_arr=($(echo "$item" | jq -r '.days[]'))
    time=$(echo "$item" | jq -r '.time')

    cron_wdays=$(days_to_cron_wday "${days_arr[@]}")

    IFS=':' read -r hour minute <<< "$time"

    cron_line="$minute $hour * * $cron_wdays $BACKUP_CMD $mode $CRON_COMMENT"

    echo "$cron_line" >> "$CRON_TMP"
    print_cmsg "Added cron job: $cron_line"
  done

  crontab "$CRON_TMP" && print_cmsg "\nCron jobs installed successfully."

  rm "$CRON_TMP"
}

# Main menu loop
while true; do
  load_schedule
  clear
  print_cmsg "Moodle Backup Scheduler\n----------------------\n"

  gum style --border normal --padding "1 2" --border-foreground 33 <<EOF
Choose an action:

1) Show current schedule
2) Add a backup schedule
3) Remove a backup schedule
4) Install/update cron jobs
5) Exit
EOF

  choice=$(gum input --prompt="Enter your choice [1-5]:")

  case "$choice" in
    1)
      clear
      load_schedule
      show_schedule
      gum confirm "Press Enter to continue..." >/dev/null
      ;;
    2)
      add_schedule
      gum confirm "Press Enter to continue..." >/dev/null
      ;;
    3)
      remove_schedule
      gum confirm "Press Enter to continue..." >/dev/null
      ;;
    4)
      install_cronjobs
      gum confirm "Press Enter to continue..." >/dev/null
      ;;
    5)
      print_cmsg "Exiting scheduler."
      exit 0
      ;;
    *)
      print_cmsg "Invalid choice."
      sleep 1
      ;;
  esac
done
