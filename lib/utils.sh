#!/bin/bash

# Utility functions

# Source colors for use in utility messages if needed, though typically logging handles this.
# SCRIPT_DIR_UTILS=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# source "${SCRIPT_DIR_UTILS}/colors.sh" # Assuming colors.sh is in the same directory

# Function to check if a command exists
# Usage: check_command "command_name"
# Returns: 0 if command exists, 1 otherwise
check_command() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check internet connectivity
# Usage: check_internet
# Returns: 0 if connected, 1 otherwise
check_internet() {
  if ping -q -c 1 -W 1 google.com &>/dev/null || ping -q -c 1 -W 1 archlinux.org &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Function to check available disk space
# Usage: check_disk_space "/path" "required_space_in_GB"
# Returns: 0 if enough space, 1 otherwise
check_disk_space() {
  local path="$1"
  local required_gb="$2"
  local available_kb
  local required_kb

  available_kb=$(df -P "$path" | awk 'NR==2 {print $4}')
  required_kb=$((required_gb * 1024 * 1024))

  if [[ "$available_kb" -ge "$required_kb" ]]; then
    return 0
  else
    return 1
  fi
}

# Function to check if the script is run as root/sudo
# Usage: check_sudo_execution
# Returns: 0 if not run as sudo, 1 if run as sudo
check_sudo_execution() {
  if [[ "$EUID" -eq 0 ]]; then
    return 1 # Is sudo
  else
    return 0 # Is not sudo
  fi
}

# Function to check if multilib repository is enabled in pacman.conf
# Usage: check_multilib
# Returns: 0 if enabled (or considered enabled in debug mode),
#          1 if not enabled and could not be (or user opted out),
#          2 if not enabled but was now actually enabled (non-debug).
check_multilib() {
  log_info "Checking for multilib repository in /etc/pacman.conf..."
  local multilib_section_exists=0
  local multilib_include_exists=0

  # Check if [multilib] and its Include line are present and not commented out
  # A more robust check for include: find [multilib], then look for Include before the next section or EOF
  if grep -q -E "^\\s*\\[multilib\\]" /etc/pacman.conf; then
    multilib_section_exists=1
    # Check if Include exists and is uncommented specifically under the active [multilib] section
    if awk '/^\s*\[multilib\]/{ f=1; next } /^\s*\[/{ f=0 } f && /^\s*Include\s*=\s*\/etc\/pacman.d\/mirrorlist/{ print }' /etc/pacman.conf | grep -q .; then
      multilib_include_exists=1
    fi
  fi

  if [[ "$multilib_section_exists" -eq 1 && "$multilib_include_exists" -eq 1 ]]; then
    log_info "Multilib section and Include line appear to be uncommented in /etc/pacman.conf."
    if [[ "${DEBUG_MODE:-0}" -eq 1 ]]; then
      log_success "[DEBUG] Multilib considered active as it's configured in /etc/pacman.conf."
      return 0 # Considered active in debug based on config
    fi

    # In non-debug, verify with pacman
    if pacman -Sii | grep -q -i 'multilib/'; then
      log_success "Multilib repository is enabled and active (verified via pacman)."
      return 0
    else
      log_warning "Multilib repository section found, but no packages detected by pacman."
      log_info "Attempting to refresh package databases with 'sudo pacman -Syyu'..."
      if sudo pacman -Syyu; then # User will be prompted for sudo password
        if pacman -Sii | grep -q -i 'multilib/'; then
          log_success "Multilib is now active after database refresh."
          return 2 # Was not active, but now is
        else
          log_error "Failed to activate multilib even after 'sudo pacman -Syyu'."
          return 1 # Still not active
        fi
      else
        log_error "'sudo pacman -Syyu' failed. Cannot ensure multilib is active."
        return 1
      fi
    fi
  else # Multilib not configured or partially configured
    log_warning "Multilib repository is not correctly enabled in /etc/pacman.conf."
    read -r -p "Do you want to attempt to enable multilib repository? (This will require sudo if not in debug mode) (Y/n): " confirm
    if [[ "$confirm" =~ ^[Yy](es)?$ || -z "$confirm" ]]; then # Default to Yes
      log_info "Attempting to enable multilib..."
      if [[ "${DEBUG_MODE:-0}" -eq 1 ]]; then
        log_debug "[DEBUG] Would simulate uncommenting [multilib] and its 'Include' line in /etc/pacman.conf."
        log_debug "[DEBUG] Would then simulate 'sudo pacman -Syyu'."
        log_info "[DEBUG] Multilib configuration 'applied' for debug purposes. Assuming success."
        return 0 # Pretend it worked in debug
      fi

      # This sed command is complex. It tries to find lines starting with # followed by [multilib]
      # or # followed by Include = /etc/pacman.d/mirrorlist (within the multilib section context - handled by awk block).
      # A safer approach for system files is often manual editing or a config management tool.
      # For this script, we provide a best effort.
      log_info "Attempting to uncomment multilib in /etc/pacman.conf. This requires sudo."
      # Make a backup
      sudo cp /etc/pacman.conf /etc/pacman.conf.bak_strix
      if sudo awk 'BEGIN{p=0} /^\s*#\s*\[multilib\]/{p=1; gsub(/^#\s*/,""); print; next} \
                         p && /^\s*#\s*Include\s*=\s*\/etc\/pacman.d\/mirrorlist/{gsub(/^#\s*/,""); p=0} \
                         {print}' /etc/pacman.conf >/tmp/pacman.conf.strix &&
        sudo mv /tmp/pacman.conf.strix /etc/pacman.conf; then
        log_success "Successfully modified /etc/pacman.conf for multilib (attempted uncomment)."
        log_info "Refreshing package databases with 'sudo pacman -Syyu'..."
        if sudo pacman -Syyu; then
          if pacman -Sii | grep -q -i 'multilib/'; then
            log_success "Multilib enabled and successfully activated after 'sudo pacman -Syyu'."
            sudo rm /etc/pacman.conf.bak_strix # Remove backup on success
            return 2                           # Was not enabled, but now is
          else
            log_error "Enabled multilib in config, but still no multilib packages found after sync."
            log_error "Please check /etc/pacman.conf. Original backed up to /etc/pacman.conf.bak_strix"
            return 1
          fi
        else
          log_error "'sudo pacman -Syyu' failed after attempting to enable multilib."
          log_error "Please check your configuration. Original backed up to /etc/pacman.conf.bak_strix"
          return 1
        fi
      else
        log_error "Failed to automatically modify /etc/pacman.conf to enable multilib. Please do it manually."
        log_info "Original backed up to /etc/pacman.conf.bak_strix (if created)."
        return 1
      fi
    else
      log_warning "User chose not to enable multilib."
      return 1 # Not enabled and user opted out
    fi
  fi
}

# Add more utility functions as needed
