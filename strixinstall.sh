#!/bin/bash

# Strix System Installer

# Exit on error
set -e

# Global arrays for tracking failures for the final report
declare -a failed_packages_global=()
declare -a failed_services_global=()

# Source library files
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=lib/colors.sh
source "${SCRIPT_DIR}/lib/colors.sh"
# shellcheck source=lib/logging.sh
source "${SCRIPT_DIR}/lib/logging.sh"
# shellcheck source=lib/utils.sh
source "${SCRIPT_DIR}/lib/utils.sh"
# shellcheck source=lib/progress.sh
source "${SCRIPT_DIR}/lib/progress.sh"

log_info "Strix System Installer started."

# --- Main Functions ---
pre_flight_checks() {
  log_section "Pre-flight Checks"
  local all_checks_passed=1 # 0 for false, 1 for true

  # 0. Check sudo (must NOT be sudo)
  log_info "Checking user privileges..."
  if ! check_sudo_execution; then # check_sudo_execution returns 1 if sudo
    log_error "This script must NOT be run with sudo or as root. Please run as a regular user."
    log_error "Certain operations like managing user-specific AUR packages (with yay) and yadm setup require it."
    log_error "If system-level changes are needed, you will be prompted for your password by the respective commands (e.g., pacman)."
    all_checks_passed=0
  else
    log_success "Running as regular user."
  fi

  # 1. Check for required commands: pacman, git, yadm, yay
  log_info "Checking for required commands (pacman, git, yadm, yay)..."
  local required_commands=("pacman" "git" "yadm")
  for cmd in "${required_commands[@]}"; do
    if check_command "$cmd"; then
      log_success "Command '$cmd' found."
    else
      log_error "Required command '$cmd' not found. Please install it and try again."
      all_checks_passed=0
    fi
  done

  # Check for yay separately
  if check_command "yay"; then
    log_success "AUR helper 'yay' is already installed."
  else
    log_warning "AUR helper 'yay' not found."
    if ! pacman -Qg base-devel &>/dev/null && [[ "$DEBUG_MODE" -ne 1 ]]; then
      log_error "Cannot install 'yay' because 'base-devel' group is not installed and was not installed in the previous step."
      all_checks_passed=0
    else
      read -r -p "Do you want to install 'yay'? (Y/n): " confirm_yay
      if [[ "$confirm_yay" =~ ^[Yy](es)?$ || -z "$confirm_yay" ]]; then
        log_info "Installing 'yay'..."
        if [[ "$DEBUG_MODE" -eq 1 ]]; then
          log_debug "[DEBUG] Would clone yay from AUR and build it."
          track_stat "yay_setup" "skipped_debug" "debug_mode"
        else
          local current_dir
          current_dir=$(pwd)
          cd "/tmp" || exit 1
          if git clone https://aur.archlinux.org/yay-bin.git &>>"$LOG_FILE"; then
            cd yay-bin || exit 1
            log_info "Building and installing yay... (This may take a moment)"
            if makepkg -si --noconfirm &>>"$LOG_FILE"; then
              log_success "'yay' installed successfully."
              track_stat "yay_setup" "installed" "success"
            else
              log_error "Failed to build or install 'yay'. Check $LOG_FILE."
              all_checks_passed=0
              track_stat "yay_setup" "install_failed" "error"
            fi
            cd "$current_dir" || exit 1
            rm -rf "/tmp/yay-bin"
          else
            log_error "Failed to clone 'yay' from AUR. Check $LOG_FILE."
            all_checks_passed=0
            track_stat "yay_setup" "clone_failed" "error"
            cd "$current_dir" || exit 1
          fi
        fi
      else
        log_warning "User chose not to install 'yay'. AUR packages might not be installable."
        track_stat "yay_setup" "user_skipped" "skipped"
      fi
    fi
  fi

  # 2. Check internet connection
  log_info "Checking internet connectivity..."
  if check_internet; then log_success "Internet connection active."; else
    log_error "No internet connection. Please connect and try again."
    all_checks_passed=0
  fi

  # 3. Check disk space
  local required_disk_gb=10
  log_info "Checking available disk space (at least ${required_disk_gb}GB for /)..."
  if check_disk_space "/" "$required_disk_gb"; then log_success "Sufficient disk space available for /."; else
    log_error "Insufficient disk space in /. At least ${required_disk_gb}GB is recommended."
    all_checks_passed=0
  fi

  # 4. Setup Multilib
  log_section "Multilib Repository Setup"
  check_multilib # This function logs its own success/warnings/errors and return status
  local multilib_status=$?
  if [[ "$multilib_status" -eq 0 ]]; then
    log_success "Multilib is active."
  elif [[ "$multilib_status" -eq 2 ]]; then
    log_success "Multilib was successfully enabled and activated."
  else log_warning "Multilib is not active or failed to enable. Some packages might not be available or work correctly."; fi
  track_stat "multilib_setup" "status_code" "$multilib_status"

  # 5. Setup base-devel
  log_section "Base Development Packages (base-devel)"
  if pacman -Qg base-devel &>/dev/null; then
    log_success "'base-devel' package group is already installed."
  else
    log_warning "'base-devel' package group not found. This is required for building AUR packages (e.g., yay)."
    read -r -p "Do you want to install 'base-devel' group? (Y/n): " confirm_bd
    if [[ "$confirm_bd" =~ ^[Yy](es)?$ || -z "$confirm_bd" ]]; then
      log_info "Installing 'base-devel' group..."
      if [[ "$DEBUG_MODE" -eq 1 ]]; then
        log_debug "[DEBUG] Would run 'sudo pacman -S --noconfirm --needed base-devel'."
        track_stat "base-devel" "skipped_debug" "debug_mode"
      else
        if sudo pacman -S --noconfirm --needed base-devel &>>"$LOG_FILE"; then
          log_success "'base-devel' group installed successfully."
          track_stat "base-devel" "installed" "success"
        else
          log_error "Failed to install 'base-devel'. AUR package builds might fail. Check $LOG_FILE."
          all_checks_passed=0
          track_stat "base-devel" "install_failed" "error"
        fi
      fi
    else
      log_warning "User chose not to install 'base-devel'. AUR package builds may fail."
      track_stat "base-devel" "user_skipped" "skipped"
    fi
  fi

  # YADM Dotfiles Setup
  log_section "Dotfiles Management (yadm)"
  local yadm_repo_url="https://github.com/xniklas/dotfiles.git"
  log_info "Checking for yadm managed dotfiles (repo: ${yadm_repo_url})..."
  if [[ -d "$HOME/.config/yadm/repo.git" || -d "$HOME/.local/share/yadm/repo.git" ]]; then
    log_info "yadm repository already cloned. Checking for updates..."
    if [[ "$DEBUG_MODE" -eq 1 ]]; then
      log_debug "[DEBUG] Would run 'yadm pull --force'"
      track_stat "yadm_dotfiles" "pull_skipped_debug" "debug_mode"
    else
      if yadm pull --force &>>"$LOG_FILE"; then
        log_success "yadm dotfiles updated forcefully."
        track_stat "yadm_dotfiles" "updated" "success"
      else
        log_warning "yadm pull failed. Your local dotfiles might be out of sync or have uncommitted changes/conflicts. Check $LOG_FILE."
        track_stat "yadm_dotfiles" "update_failed" "warning"
      fi
    fi
  else
    log_info "Cloning yadm dotfiles from ${yadm_repo_url}..."
    if [[ "$DEBUG_MODE" -eq 1 ]]; then
      log_debug "[DEBUG] Would run 'yadm clone ${yadm_repo_url}'"
      track_stat "yadm_dotfiles" "clone_skipped_debug" "debug_mode"
    else
      if yadm clone "${yadm_repo_url}" &>>"$LOG_FILE"; then
        log_success "yadm dotfiles cloned successfully."
        track_stat "yadm_dotfiles" "cloned" "success"
      else
        log_error "Failed to clone yadm dotfiles from ${yadm_repo_url}. Check $LOG_FILE."
        track_stat "yadm_dotfiles" "clone_failed" "error"
        # Not necessarily a script-halting failure, user might not want dotfiles setup now.
      fi
    fi
  fi

  # Final pre-flight check status
  if [[ "$all_checks_passed" -eq 0 ]]; then
    log_error "One or more critical pre-flight checks or setup steps failed. Please review the messages above. Exiting."
    exit 1
  else
    log_success "All critical pre-flight checks and essential setups passed."
  fi
  log_info "Pre-flight checks and initial setup completed."
}

SELECTED_GPU_PACKAGES_VAR_NAME=""

configure_installation() {
  log_section "Installation Configuration"
  # GPU Detection and Selection (full logic from previous steps is assumed for brevity here)
  log_info "Detecting video hardware..."
  local gpus
  gpus=$(lspci -k | grep -EA3 'VGA|3D|Display' | grep -i 'kernel driver in use:' | awk -F': ' '{print $2}' | sort -u)
  local gpu_devices
  gpu_devices=$(lspci | grep -E 'VGA|3D|Display' | awk -F': ' '{print $3}' | sed -e 's/\[[0-9a-zA-Z]*\]//g' | sed 's/(rev [0-9a-fA-F]*)//g' | sed 's/ Corporation//g' | sort -u)
  local detected_type="UNKNOWN"
  local nvidia_detected=0 amd_detected=0 intel_detected=0 vmware_detected=0 virtualbox_detected=0 qemu_kvm_detected=0
  if echo "$gpus" | grep -q -i "nvidia"; then
    nvidia_detected=1
    detected_type="NVIDIA"
  fi
  if echo "$gpus" | grep -q -i "amdgpu"; then
    amd_detected=1
    detected_type="AMD"
  fi
  if echo "$gpus" | grep -q -i "i915"; then
    intel_detected=1
    detected_type="INTEL"
  fi
  # ... (add other detections: vmware_detected, virtualbox_detected, qemu_kvm_detected)
  if [[ "$detected_type" == "UNKNOWN" ]]; then # Fallback to device names
    if echo "$gpu_devices" | grep -q -i "NVIDIA"; then
      nvidia_detected=1
      detected_type="NVIDIA"
    fi
    # ... (add other fallback detections)
  fi
  # log_info "Detected GPU Drivers: $gpus"; log_info "Detected GPU Devices: $gpu_devices"

  local options=()
  if [[ "$nvidia_detected" -eq 1 ]]; then
    log_info "${BOLD_CYAN}NVIDIA GPU detected.${RESET}"
    options+=("NVIDIA_PROPRIETARY" "NVIDIA (Proprietary)" "NVIDIA_OPEN" "NVIDIA (Open Source)")
  fi
  if [[ "$amd_detected" -eq 1 ]]; then
    log_info "${BOLD_CYAN}AMD GPU detected.${RESET}"
    options+=("AMD" "AMD")
  fi
  if [[ "$intel_detected" -eq 1 ]]; then
    log_info "${BOLD_CYAN}Intel GPU detected.${RESET}"
    options+=("INTEL" "Intel")
  fi
  # ... (add VMware, VirtualBox, QEMU_KVM to options if detected)
  options+=("GENERIC_MESA" "Generic Mesa (Fallback)" "SKIP_GPU" "Skip GPU driver installation")

  log_info "Please select your GPU driver set:"
  local menu_items=()
  for ((i = 0; i < ${#options[@]}; i += 2)); do menu_items+=("${options[i]}" "${options[i + 1]}"); done
  if check_command "whiptail"; then
    local chosen_tag
    chosen_tag=$(whiptail --title "GPU Driver Selection" --menu "Choose your GPU driver set:" 18 78 10 "${menu_items[@]}" 3>&1 1>&2 2>&3)
    if [[ $? -eq 0 ]]; then
      SELECTED_GPU_PACKAGES_VAR_NAME="${chosen_tag}_DRIVERS"
      log_success "User selected: ${chosen_tag}"
    else
      SELECTED_GPU_PACKAGES_VAR_NAME="SKIP_GPU"
      log_warning "No GPU driver set selected or selection cancelled."
    fi
  else
    log_warning "'whiptail' not found. Using basic select for GPU driver selection."
    PS3="Select GPU option: "
    select opt_val in "${menu_items[@]}"; do
      if [[ -n "$opt_val" ]]; then
        # Find the tag that corresponds to the chosen value (description)
        for ((j = 0; j < ${#menu_items[@]}; j += 2)); do
          if [[ "${menu_items[j + 1]}" == "$opt_val" ]]; then
            SELECTED_GPU_PACKAGES_VAR_NAME="${menu_items[j]}_DRIVERS"
            log_success "User selected: ${menu_items[j]}"
            break 2
          fi
        done
      else log_error "Invalid selection."; fi
    done
    if [[ -z "$SELECTED_GPU_PACKAGES_VAR_NAME" ]]; then
      SELECTED_GPU_PACKAGES_VAR_NAME="SKIP_GPU"
      log_warning "No GPU selected."
    fi
  fi
  # Correct if _DRIVERS was appended to SKIP_GPU
  if [[ "$SELECTED_GPU_PACKAGES_VAR_NAME" == "SKIP_GPU_DRIVERS" ]]; then SELECTED_GPU_PACKAGES_VAR_NAME="SKIP_GPU"; fi
  track_stat "gpu_selection" "selected" "$SELECTED_GPU_PACKAGES_VAR_NAME"
  log_info "Installation configuration completed."
}

install_packages() {
  log_section "Package Installation"
  failed_packages_global=() # Initialize global array
  local successfully_installed_packages=()

  if [[ -f "${SCRIPT_DIR}/config/packages.conf" ]]; then source "${SCRIPT_DIR}/config/packages.conf"; else log_warning "packages.conf missing"; fi
  if [[ -f "${SCRIPT_DIR}/config/gpu-drivers.conf" ]]; then source "${SCRIPT_DIR}/config/gpu-drivers.conf"; else log_warning "gpu-drivers.conf missing"; fi

  local all_packages_to_install=()
  local general_package_categories=(
    BASE_SYSTEM COMMON_DRIVERS HYPRLAND NETWORKING AUDIO WAYLAND UI_THEMING FILE_MANAGEMENT MULTIMEDIA
    PRODUCTIVITY MEDIA_GRAPHICS DEVELOPMENT SHELL_TERMINAL ARCHIVE_TOOLS SEARCH_NAV SYSTEM_UTILS FONTS SECURITY PRINTING MISCELLANEOUS
  )
  for cat_array_name in "${general_package_categories[@]}"; do
    if declare -p "$cat_array_name" 2>/dev/null | grep -q 'declare -a'; then
      eval "all_packages_to_install+=(\"\${${cat_array_name}[@]}\")"
    fi
  done
  if [[ -n "$SELECTED_GPU_PACKAGES_VAR_NAME" && "$SELECTED_GPU_PACKAGES_VAR_NAME" != "SKIP_GPU" ]]; then
    if declare -p "$SELECTED_GPU_PACKAGES_VAR_NAME" 2>/dev/null | grep -q 'declare -a'; then
      eval "all_packages_to_install+=(\"\${${SELECTED_GPU_PACKAGES_VAR_NAME}[@]}\")"
    fi
  fi

  all_packages_to_install=($(echo "${all_packages_to_install[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
  if [[ ${#all_packages_to_install[@]} -eq 0 ]]; then
    log_warning "No packages to install."
    return
  fi
  log_info "Targeting ${#all_packages_to_install[@]} unique packages for installation."

  if [[ "${DEBUG_MODE:-0}" -eq 1 ]]; then
    log_info "${BOLD_YELLOW}[DEBUG] Would attempt to install the following ${#all_packages_to_install[@]} packages:${RESET}"
    for pkg_idx in "${!all_packages_to_install[@]}"; do
      local pkg_num=$((pkg_idx + 1))
      local pkg_to_log="${all_packages_to_install[$pkg_idx]}"
      log_info "${BOLD_YELLOW}[DEBUG] ${pkg_num}/${#all_packages_to_install[@]} -> ${pkg_to_log}${RESET}"
      track_stat "package_${pkg_to_log//[^a-zA-Z0-9_]/_}" "install_skipped_debug" "debug_mode"
      successfully_installed_packages+=("$pkg_to_log")
    done
    log_info "Package installation phase finished (DEBUG mode - no actual changes made)."
    return
  fi

  local PKG_MANAGER="yay"
  if ! check_command "yay"; then PKG_MANAGER="sudo pacman"; fi
  log_info "Using '${PKG_MANAGER}' for installing ${#all_packages_to_install[@]} packages..."
  for pkg_idx in "${!all_packages_to_install[@]}"; do
    local pkg="${all_packages_to_install[$pkg_idx]}"
    local pkg_num=$((pkg_idx + 1))
    log_info "Installing package ${pkg_num}/${#all_packages_to_install[@]}: ${BOLD_CYAN}${pkg}${RESET}"
    local log_f="${SCRIPT_DIR}/install_log_${pkg//[^a-zA-Z0-9._-]/_}.log"
    start_spinner "Pkg ${pkg_num}/${#all_packages_to_install[@]}: ${L_PKG} (Log: ./${log_f##*/})"
    (eval "${PKG_MANAGER} -S --noconfirm --needed ${pkg}") &>"$log_f"
    local status=$?
    stop_spinner $status
    echo -e "\n--- Log for ${pkg} (Status: ${status}) ---" >>"$LOG_FILE"
    cat "$log_f" >>"$LOG_FILE"
    echo "--- End log ---" >>"$LOG_FILE"
    if [[ $status -eq 0 ]]; then
      log_success "Successfully installed/verified ${pkg}."
      successfully_installed_packages+=("$pkg")
      track_stat "package_${pkg//[^a-zA-Z0-9_]/_}" "installed" "success"
      rm -f "$log_f"
    else
      log_error "Failed to install ${pkg}. Exit Status: ${status}. Log: $log_f"
      failed_packages_global+=("$pkg (status: $status)")
      track_stat "package_${pkg//[^a-zA-Z0-9_]/_}" "install_failed" "status $status"
    fi
  done
  log_info "Package installation phase finished."
}

configure_system() {
  log_section "System Configuration"
  log_info "Further system settings (including UWSM if defined) will be handled if specified."
  if [[ "${DEBUG_MODE:-0}" -eq 1 ]]; then
    log_debug "[DEBUG] Placeholder for UWSM and other system configurations."
  else
    log_info "No specific system configurations (like UWSM) implemented yet."
  fi
  log_info "System configuration phase finished."
}

manage_services() {
  log_section "Service Management"
  failed_services_global=() # Initialize global array
  local services_config_file="${SCRIPT_DIR}/config/services.conf"
  if [[ ! -f "$services_config_file" ]]; then
    log_warning "Service config file not found: $services_config_file. Skipping."
    return
  fi

  local all_service_lines
  mapfile -t all_service_lines < <(grep -vE '^\s*(#|$)' "$services_config_file")
  if [[ ${#all_service_lines[@]} -eq 0 ]]; then
    log_info "No services listed in $services_config_file."
    return
  fi
  log_info "Processing ${#all_service_lines[@]} service entries from $services_config_file."

  local managed_ok=0 managed_fail=0
  for service_entry in "${all_service_lines[@]}"; do
    local service_name_raw="$service_entry"
    local is_user_service=0
    local systemctl_base_cmd="systemctl"
    local type_label="system"

    if [[ "$service_entry" == user:* ]]; then
      service_name_raw="${service_entry#user:}"
      is_user_service=1
      systemctl_base_cmd="systemctl --user"
      type_label="user"
    fi
    service_name_raw=$(echo "$service_name_raw" | xargs) # Trim whitespace

    if [[ ! "$service_name_raw" =~ ^[a-zA-Z0-9@._-]+(\.service)?$ ]]; then
      log_warning "Invalid ${type_label} service name format: \'$service_name_raw\' (from \'${service_entry}\'). Skipping."
      failed_services_global+=("$service_entry (invalid name)")
      managed_fail=$((managed_fail + 1))
      track_stat "svc_${service_name_raw//[^a-zA-Z0-9_]/_}" "invalid_name" "skipped"
      continue
    fi
    # Ensure .service suffix for clarity, systemd often handles it but explicit is better
    [[ "$service_name_raw" != *.service ]] && service_name_raw+=".service"

    log_info "Managing ${type_label} service: ${BOLD_CYAN}$service_name_raw${RESET}"
    if [[ "${DEBUG_MODE:-0}" -eq 1 ]]; then
      log_debug "[DEBUG] Would run '${systemctl_base_cmd} enable --now ${service_name_raw}'."
      track_stat "svc_${service_name_raw//[^a-zA-Z0-9_]/_}_${type_label}" "skipped_debug" "debug_mode"
      managed_ok=$((managed_ok + 1))
    else
      local unit_check_cmd="${systemctl_base_cmd} list-unit-files --type=service"
      # Check if service unit exists. User service check might be tricky without proper D-Bus session.
      if ! $unit_check_cmd --all | grep -qwE "^${service_name_raw}(\s|$)" &>/dev/null; then # Grep for the service name in the output
        log_warning "${type_label^} service unit \'${service_name_raw}\' not found. It might not be installed or is mistyped. Skipping."
        failed_services_global+=("$service_name_raw ($type_label, not found)")
        managed_fail=$((managed_fail + 1))
        track_stat "svc_${service_name_raw//[^a-zA-Z0-9_]/_}_${type_label}" "not_found" "skipped"
        continue
      fi

      if [[ "$is_user_service" -eq 1 ]] && [[ -z "$XDG_RUNTIME_DIR" ]]; then
        log_warning "XDG_RUNTIME_DIR not set. Managing D-Bus user service '${service_name_raw}' might require it."
        log_warning "Consider 'loginctl enable-linger $(whoami)' for boot-time user services."
      fi

      start_spinner "Enabling/starting ${type_label} service ${service_name_raw}"
      local manage_cmd="${systemctl_base_cmd} enable --now \"${service_name_raw}\""
      if eval "$manage_cmd" &>>"$LOG_FILE"; then
        stop_spinner 0
        log_success "Successfully managed ${type_label} service ${service_name_raw}."
        managed_ok=$((managed_ok + 1))
        track_stat "svc_${service_name_raw//[^a-zA-Z0-9_]/_}_${type_label}" "managed" "success"
      else
        local status=$?
        stop_spinner $status
        log_error "Failed to manage ${type_label} service ${service_name_raw} (status $status). Check $LOG_FILE."
        failed_services_global+=("$service_name_raw ($type_label, failed status: $status)")
        managed_fail=$((managed_fail + 1))
        track_stat "svc_${service_name_raw//[^a-zA-Z0-9_]/_}_${type_label}" "failed" "status $status"
        (eval "${systemctl_base_cmd} status \"${service_name_raw}\" --no-pager -l") &>>"$LOG_FILE" || true
      fi
    fi
  done
  log_info "Service management phase finished."
}

optimize_system() {
  log_section "System Optimization"
  if [[ "${DEBUG_MODE:-0}" -eq 1 ]]; then
    log_debug "[DEBUG] Placeholder for system optimizations."
  else
    log_info "No specific system optimizations implemented yet."
  fi
  log_info "System optimization phase finished."
}

show_report() {
  log_section "Installation Summary Report"
  log_info "Displaying collected statistics from: $STATS_FILE"
  if [[ -s "$STATS_FILE" ]]; then sed 's/^/    /' "$STATS_FILE"; else log_info "    No statistics were tracked."; fi
  echo
  if [[ ${#failed_packages_global[@]} -gt 0 ]]; then
    log_error "${#failed_packages_global[@]} package(s) failed to install correctly:"
    for pkg_f in "${failed_packages_global[@]}"; do log_error "    - $pkg_f"; done
    log_warning "Check $LOG_FILE and individual install_log_*.log files for details."
  else log_success "All targeted packages processed successfully (or skipped in debug)."; fi
  echo
  if [[ ${#failed_services_global[@]} -gt 0 ]]; then
    log_error "${#failed_services_global[@]} service(s) failed to manage correctly:"
    for svc_f in "${failed_services_global[@]}"; do log_error "    - $svc_f"; done
    log_warning "Check $LOG_FILE for systemctl output related to these services."
  else log_success "All targeted services processed successfully (or skipped in debug)."; fi
  echo
  log_info "${BOLD_GREEN}--- Next Steps ---${RESET}"
  log_info "1. Review the full installation log: ${BOLD_WHITE}${LOG_FILE}${RESET}"
  log_info "2. Review the statistics log: ${BOLD_WHITE}${STATS_FILE}${RESET}"
  if [[ ${#failed_packages_global[@]} -gt 0 || ${#failed_services_global[@]} -gt 0 ]]; then
    log_warning "Address any reported failures before proceeding or rebooting."
  fi
  log_info "3. It is highly recommended to ${BOLD_YELLOW}REBOOT${RESET} your system for all changes to take effect."
  log_info "End of Strix System Installation Report."
}

# --- Argument Parsing ---
DEBUG_MODE=0 # Default to off (0 for false, 1 for true)
while [[ $# -gt 0 ]]; do
  case "$1" in
  -d | --debug)
    DEBUG_MODE=1
    shift
    ;;
  *)
    log_error "Unknown option: $1"
    exit 1
    ;;
  esac
done
if [[ "$DEBUG_MODE" -eq 1 ]]; then log_info "${BOLD_YELLOW}Debug mode enabled. No system changes will be made.${RESET}"; fi

# --- Script Flow ---
main() {
  pre_flight_checks
  configure_installation
  install_packages
  configure_system
  manage_services
  optimize_system
  show_report
  log_info "${BOLD_GREEN}Strix System installation completed! See report above.${RESET}"
}
main
