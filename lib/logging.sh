#!/bin/bash

# Logging functions

# Ensure SCRIPT_DIR is available or correctly determined for sourcing colors.sh
# If this script is sourced by strixinstall.sh, SCRIPT_DIR should be set there.
# If running this script standalone for tests, SCRIPT_DIR might need explicit setting:
# SCRIPT_DIR_LOGGING=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

if [[ -z "$SCRIPT_DIR" ]]; then
  # Fallback if SCRIPT_DIR isn't set, assuming it's in the same dir as colors.sh
  local current_script_path
  current_script_path=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
  if [[ -f "${current_script_path}/colors.sh" ]]; then
    # shellcheck source=colors.sh
    source "${current_script_path}/colors.sh"
  else
    echo "Error: colors.sh not found by logging.sh. SCRIPT_DIR may be missing." >&2
    # Define fallback colors or exit if colors are critical
    RESET=''
    RED=''
    GREEN=''
    YELLOW=''
    BOLD_RED=''
    BOLD_GREEN=''
    BOLD_YELLOW=''
  fi
else
  # shellcheck source=lib/colors.sh
  source "${SCRIPT_DIR}/lib/colors.sh"
fi 

LOG_FILE="${SCRIPT_DIR}/strix_install.log"
STATS_FILE="${SCRIPT_DIR}/strix_stats.log" # For tracking stats

# Function to ensure log files exist
ensure_log_files_exist() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    touch "$STATS_FILE"
}

# Call it once to make sure log files are ready
ensure_log_files_exist

# Base log function
_log() {
    local type_color="$1"
    local type_label="$2"
    local message="$3"
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    # Log to console with color
    echo -e "${type_color}[ ${type_label} ]${RESET} ${message}"
    
    # Log to file without color codes
    echo "[ ${timestamp} ][ ${type_label} ] ${message}" >> "$LOG_FILE"
}

log_info() {
    _log "${CYAN}" "INFO" "$1"
}

log_success() {
    _log "${BOLD_GREEN}" "SUCCESS" "$1"
}

log_warning() {
    _log "${BOLD_YELLOW}" "WARNING" "$1"
}

log_error() {
    # Errors go to stderr as well
    local message="$1"
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo -e "${BOLD_RED}[ ERROR ]${RESET} ${message}" >&2
    echo "[ ${timestamp} ][ ERROR ] ${message}" >> "$LOG_FILE"
}

log_debug() {
    if [[ "${DEBUG_MODE:-0}" -eq 1 ]]; then # Check DEBUG_MODE, default to 0 if not set
        _log "${MAGENTA}" "DEBUG" "$1"
    fi
}

# Functions for stats tracking
# Usage: track_stat "item_name" "status (e.g., installed, failed, time_taken_ms)" "details/value"
track_stat() {
    local item="$1"
    local status="$2"
    local value="$3"
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[ ${timestamp} ] STAT: ${item} | Status: ${status} | Value: ${value}" >> "$STATS_FILE"
}

# Function to log a section header
log_section() {
    local message="$1"
    echo -e "\n${BOLD_BLUE}--- ${message} ---${RESET}"
    echo "--- ${message} ---" >> "$LOG_FILE"
}
