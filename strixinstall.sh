#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
  echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[$(date +'%H:%M:%S')] WARNING:${NC} $1"
}

error() {
  echo -e "${RED}[$(date +'%H:%M:%S')] ERROR:${NC} $1"
  exit 1
}

# Check if running as root
check_root() {
  if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root. Run as a regular user."
  fi
}

# Check if we're in Arch Linux
check_arch() {
  if [[ ! -f /etc/arch-release ]]; then
    error "This script is designed for Arch Linux only."
  fi
}

# Update system and install base dependencies
install_dependencies() {
  log "Updating system packages..."
  sudo pacman -Syu --noconfirm

  log "Installing Python and Rich..."
  sudo pacman -S --noconfirm python python-pip python-rich

  # Install yay if not present (for AUR packages)
  if ! command -v yay &>/dev/null; then
    log "Installing yay AUR helper..."

    # Install base-devel if not present
    sudo pacman -S --noconfirm base-devel git

    # Clone and install yay
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~

    log "✓ yay installed successfully"
  else
    log "✓ yay is already installed"
  fi
}

# Download the Python script if it doesn't exist
setup_installer_script() {
  SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
  PYTHON_SCRIPT="installer.py"

  if [[ ! -f "$PYTHON_SCRIPT" ]]; then
    error "installer.py not found in the same directory as this script!"
  fi

  # Make it executable
  chmod +x "$PYTHON_SCRIPT"
  log "✓ Python installer script ready"
}

# Main function
main() {
  echo -e "${BLUE}"
  echo "╔════════════════════════════════════════╗"
  echo "║        Arch Linux Auto-Installer       ║"
  echo "║             Setup Script               ║"
  echo "╚════════════════════════════════════════╝"
  echo -e "${NC}"

  log "Starting Arch Linux Auto-Installer setup..."

  # Perform checks
  check_root
  check_arch

  # Setup
  log "Installing dependencies..."
  install_dependencies

  log "Setting up installer script..."
  setup_installer_script

  log "Setup complete! Starting the installer..."
  echo ""

  # Run the Python installer
  SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
  python "installer.py"
}

# Trap to handle interrupts
trap 'echo -e "\n${YELLOW}Setup interrupted by user${NC}"; exit 1' INT

# Run main function
main "$@"
