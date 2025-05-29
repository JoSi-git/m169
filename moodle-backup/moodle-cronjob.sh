#!/bin/bash

# Moodle Backup Scheduler with Gum
# Author: JoSi
# Last Update: 2025-05-28
# Description: Interactive schedule manager using gum to configure backup cronjobs.

print_cmsg() {
  if [[ "$1" == "-n" ]]; then
    shift
    echo -ne "\e[1m$*\e[0m"
  else
    echo -e "\e[1m$*\e[0m"
  fi
}

# Load .env
if [[ -f "./.env" ]]; then
  source "./.env"
  print_cmsg ".env file found and loaded from local directory."
else
  print_cmsg ".env file wasn't found in local directory. Exiting."
  exit 1
fi

SCHEDULE_FILE="$INSTALL_DIR/tools/moodle-backup/moodle-backup-schedule.json"
CRON_COMMENT="# Moodle Docker Backup Scheduler"
BACKUP_CMD="$INSTALL_DIR/tools/moodle-backup/moodle-backup.sh"
CRON_TMP=$(mktemp)

# Map weekday names to cron weekday numbers
declare -A DAY_TO_CRON=(
  [Sunday]=0 [Monday]=1 [Tuesday]=2 [Wednesday]=3
  [Thursday]=4 [Friday]=5 [Saturday]=6
)

days_to_cron_wday() {
  local days=("$@")
  local cron_days=()
  for d in "${days[@]}"; do
    cron_days+=("${DAY_TO_CRON[$d]}")
  done
  IFS=','; echo "${cron_days[*]}"
}

# Ensure schedule file exists and remove invalid entries
sanitize_schedule_file() {
  if [[ ! -f "$SCHEDULE_FILE" ]]; then
    echo "[]" > "$SCHEDULE_FILE"
  fi

  # Remove entries with missing mode, days, or time
  jq '[.[] | select(.mode != "" and (.days | length > 0) and .time != "")]' "$SCHEDULE_FILE" > "${SCHEDULE_FILE}.tmp" && mv "${SCHEDULE_FILE}.tmp" "$SCHEDULE_FILE"
}

# Load schedule JSON into bash array
load_schedule() {
  sanitize_schedule_file
  mapfile -t schedule < <(jq -c '.[]' "$SCHEDULE_FILE")
}

# Show current schedule entries in a nice table
show_schedule() {
  if [[ ! -s "$SCHEDULE_FILE" ]]; then
    print_cmsg "No backup schedules defined yet."
    return
  fi

  printf '\033[38;5;33mCurrent backup schedules:\n-------------------------------\n\033[0m'
  echo
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

add_schedule() {
  local modes=("full" "db-only" "moodle-only")
  local mode=$(gum choose "${modes[@]}")

  local all_days=(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)

  # Einfach nur einen Tag auswählen
  echo "Wähle einen Tag:"
  local selected_day=$(gum choose "${all_days[@]}")

  # days als JSON-Array mit einem Tag
  local json_days=$(jq -n --arg day "$selected_day" '[$day]')

  local time
  while true; do
    time=$(gum input --prompt="Enter backup time (HH:MM 24h format):" --placeholder="")
    if [[ "$time" =~ ^([01][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
      break
    else
      gum style --foreground=red --bold "Invalid time format. Please enter time in 24-hour format like 09:00 or 18:45."
    fi
  done

  jq --arg mode "$mode" --argjson days "$json_days" --arg time "$time" \
    '. += [{"mode": $mode, "days": $days, "time": $time}]' "$SCHEDULE_FILE" > "${SCHEDULE_FILE}.tmp" && mv "${SCHEDULE_FILE}.tmp" "$SCHEDULE_FILE"

  print_cmsg "New schedule added: Mode=$mode, Day=$selected_day, Time=$time"
}

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

  local choice=$(gum choose "${options[@]}")
  [[ -z "$choice" ]] && print_cmsg "No selection made." && return

  local num=${choice%%)*}
  num=$((num))

  jq "del(.[$((num-1))])" "$SCHEDULE_FILE" > "${SCHEDULE_FILE}.tmp" && mv "${SCHEDULE_FILE}.tmp" "$SCHEDULE_FILE"
  print_cmsg "Removed schedule entry #$num."
}

install_cronjobs() {
  load_schedule
  print_cmsg "Installing cron jobs from schedule...\n"

  crontab -l 2>/dev/null | grep -v "$CRON_COMMENT" > "$CRON_TMP" || true
  mapfile -t current_cron < "$CRON_TMP"

  cronjob_exists() {
    local job="$1"
    for line in "${current_cron[@]}"; do
      [[ "$line" == "$job" ]] && return 0
    done
    return 1
  }

  for item in "${schedule[@]}"; do
    mode=$(echo "$item" | jq -r '.mode')
    readarray -t days_arr < <(echo "$item" | jq -r '.days[]')
    time=$(echo "$item" | jq -r '.time')

    # Validierung
    if [[ -z "$mode" || ${#days_arr[@]} -eq 0 || -z "$time" ]]; then
      print_cmsg "Skipping invalid schedule entry: $item"
      continue
    fi

    cron_wdays=$(days_to_cron_wday "${days_arr[@]}")
    if ! IFS=':' read -r hour minute <<< "$time"; then
      print_cmsg "Invalid time format in: $time"
      continue
    fi

    cron_line="$minute $hour * * $cron_wdays $BACKUP_CMD $mode $CRON_COMMENT"

    if cronjob_exists "$cron_line"; then
      print_cmsg "Cron job already exists, skipping: $cron_line"
    else
      echo "$cron_line" >> "$CRON_TMP"
      print_cmsg "Added cron job: $cron_line"
    fi
  done

  if crontab "$CRON_TMP"; then
    print_cmsg "\nCron jobs installed successfully."
  else
    print_cmsg "\nFailed to install cron jobs!"
  fi

  rm -f "$CRON_TMP"
}

# Main menu loop
while true; do
  load_schedule
  clear

  printf '\033[38;5;33mMoodle Backup Scheduler\n-------------------------------\n\033[0m'
  gum style --border normal --padding "1 2" --border-foreground 33 <<EOF
Choose an action:

1) Show current schedule
2) Add a backup schedule
3) Remove a backup schedule
4) Install/update cron jobs
5) Exit
EOF

  choice=$(gum input --prompt="Enter your choice [1-5]:" --placeholder " ")

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