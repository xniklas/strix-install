#!/bin/bash

# Progress bar/spinner functions

# Source colors if not already available
if [[ -z "$SCRIPT_DIR" ]] && [[ -f "./colors.sh" ]]; then # Basic check if run standalone
  source "./colors.sh"
elif [[ -n "$SCRIPT_DIR" ]] && [[ -f "${SCRIPT_DIR}/lib/colors.sh" ]]; then
  source "${SCRIPT_DIR}/lib/colors.sh"
fi

_PROGRESS_PID=0
_SPINNER_CHARS=("| L O A D I N G |" "| L O A D I N G |" "| L O A D I N G |" "| L O A D I N G |" "| L O A D I N G |" "| L O A D I N G |" "| L O A D I N G |" "| L O A D I N G |" "| L O A D I N G |" "| L O A D I N G |" "v L O A D I N G v" "v L O A D I N G v" "v L O A D I N G v" "v L O A D I N G v" "v L O A D IN G v" "v L O A D I N G v" "v L O A D I N G v" "v L O A D I N G v" "v L O A D I N G v" "v L O A D I N G v" "< L O A D I N G <" "< L O A D I N G <" "< L O A D I N G <" "< L O A D I N G <" "< L O A D I N G <" "< L O A D I N G <" "< L O A D I N G <" "< L O A D I N G <" "< L O A D I N G <" "< L O A D I N G <" "^ L O A D I N G ^" "^ L O A D I N G ^" "^ L O A D I N G ^" "^ L O A D I N G ^" "^ L O A D I N G ^" "^ L O A D I N G ^" "^ L O A D I N G ^" "^ L O A D I N G ^" "^ L O A D I N G ^" "^ L O A D I N G ^") # Simple spinner
_SPINNER_DELAY=0.1

# Start a simple spinner for a background command
# Usage: start_spinner "Doing something..." "$command_pid"
start_spinner() {
  local message="${1:-Processing...}"
  local target_pid="$2"

  # Hide cursor
  tput civis
  echo -n -e "${CYAN}${message}${RESET} "

  {
    while true; do
      # Check if the target PID still exists
      if [[ -n "$target_pid" ]] && ! ps -p "$target_pid" >/dev/null; then
        break # Target process finished
      fi
      # If no PID given, it spins until stop_spinner is called
      for char in "${_SPINNER_CHARS[@]}"; do
        echo -n -e "${BOLD_YELLOW}${char}${RESET}"
        sleep "$_SPINNER_DELAY"
        echo -n -e "\r${CYAN}${message}${RESET} " # Erase spinner with message
      done
    done
  } &
  _PROGRESS_PID=$!
  # Disown the spinner process so it doesn't get killed if the parent shell exits uncleanly
  # and to prevent "Killed" message on script exit if spinner is still running.
  disown "$_PROGRESS_PID" &>/dev/null
}

# Stop the spinner
# Usage: stop_spinner $?
#        Pass the exit status of the command
stop_spinner() {
  local original_exit_status="${1:-0}"

  if [[ "$_PROGRESS_PID" -ne 0 ]] && ps -p "$_PROGRESS_PID" >/dev/null; then
    # Gently try to kill the spinner subshell and its children (sleep)
    pkill -P "$_PROGRESS_PID" &>/dev/null
    kill "$_PROGRESS_PID" &>/dev/null
    wait "$_PROGRESS_PID" &>/dev/null # Wait for it to actually terminate
  fi
  _PROGRESS_PID=0

  # Clear the line where spinner was (up to a certain length)
  echo -n -e "\r$(printf ' %.0s' {1..80})\r"

  # Show cursor
  tput cnorm

  return "$original_exit_status" # Return the original exit status
}

# Example of using pv for progress if available.
# install_with_pv() {
#   local package_name="$1"
#   log_info "Attempting to install $package_name with pv progress..."
#   if check_command yay && check_command pv; then
#       (yay -S --noconfirm --needed "$package_name" 2>&1 | pv -lep -s $(yay -Si "$package_name" | grep "Download Size" | awk '{print $4}') ) || log_error "Failed to install $package_name"
#   elif check_command pacman && check_command pv; then # Fallback for official
#       (sudo pacman -S --noconfirm --needed "$package_name" 2>&1 | pv -lep -s $(pacman -Si "$package_name" | grep "Download Size" | awk '{print $4}')) || log_error "Failed to install $package_name"
#   else
#       log_warning "pv or yay/pacman not available, installing $package_name without detailed progress..."
#       # Add standard install command here
#   fi
# }

# Note: The pv example above needs refinement for Download Size parsing and error handling.
# For pacman/yay, their own progress bars are usually sufficient if not redirecting stdout entirely.
# If redirecting stdout for logging, then a spinner is a good general UX.
