#!/bin/bash

# Moodle Backup Scheduler with Gum
# Author: JoSi
# Last Update: 2025-05-28
# Description: Interactive schedule manager using gum to configure backup cronjobs.

# Function: Prints the given text in bold on the console
print_cmsg() {
  if [[ "$1" == "-n" ]]; then
    shift
    echo -ne "\e[1m$*\e[0m"
  else
    echo -e "\e[1m$*\e[0m"
  fi
}

# Load environment variables from .env
if [[ -f "./.env" ]]; then
  source "./.env"
  print_cmsg ".env file found and loaded from local directory."
else
  print_cmsg ".env file wasn't found in local directory. Exiting."
  exit 1
fi

SCHEDULE_FILE="./moodle-backup-schedule.json"
CRON_COMMENT="# Moodle Docker Backup Scheduler"
BACKUP_CMD="./moodle-backup.sh"
CRON_TMP=$(mktemp)

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
  local modes=("--full" "--db-only" "--moodle-only")
  local mode
  mode=$(gum choose "${modes[@]}")

  local all_days=(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)
  local days
  days=$(gum choose --no-limit "${all_days[@]}")

  local time
  while true; do
    time=$(gum input --prompt="Enter backup time (HH:MM 24h format):")
    if [[ "$time" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
      break
    else
      gum style --foreground=red --bold "Invalid time format. Please enter HH:MM (24h)."
    fi
  done

  local json_days
  json_days=$(printf '%s\n' $days | jq -R . | jq -s .)

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

  local num=${choice%%)*}
  num=$((num))

  jq "del(.[$((num-1))])" "$SCHEDULE_FILE" > "${SCHEDULE_FILE}.tmp" && mv "${SCHEDULE_FILE}.tmp" "$SCHEDULE_FILE"
  print_cmsg "Removed schedule entry #$num."
}

# Install cron jobs from schedule
install_cronjobs() {
  load_schedule
  print_cmsg "Installing cron jobs from schedule...\n"

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

  # Title
  printf '\033[38;5;33mMoodle Backup Scheduler\n-------------------------------\n\033[0m'

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
      read -n 1 -s -r -p "Press any key to continue..."
      ;;
    2)
      add_schedule
      read -n 1 -s -r -p "Press any key to continue..."
      ;;
    3)
      remove_schedule
      read -n 1 -s -r -p "Press any key to continue..."
      ;;
    4)
      install_cronjobs
      read -n 1 -s -r -p "Press any key to continue..."
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