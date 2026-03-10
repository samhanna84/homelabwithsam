#!/bin/bash
# ==============================================================================
# system-update.sh — Full system update script for Debian
# Updates: APT packages, Flatpaks, Snaps, then reboots
# ==============================================================================

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Helpers ---
log()     { echo -e "${BLUE}${BOLD}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}[ERROR]${RESET} $*" >&2; }
section() { echo -e "\n${BOLD}==============================${RESET}"; echo -e "${BOLD} $*${RESET}"; echo -e "${BOLD}==============================${RESET}"; }

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
  error "This script must be run as root. Try: sudo $0"
  exit 1
fi

REBOOT_DELAY=10

section "🔄 Starting Full System Update"
echo "Started at: $(date)"

# ==============================================================================
# 1. APT — Debian packages
# ==============================================================================
section "📦 APT — Debian Packages"

log "Updating package lists..."
if apt-get update -qq; then
  success "Package lists updated."
else
  error "apt-get update failed. Check your sources."
  exit 1
fi

log "Upgrading installed packages..."
if apt-get upgrade -y; then
  success "Packages upgraded."
else
  error "apt-get upgrade failed."
  exit 1
fi

log "Running full upgrade (dist-upgrade)..."
if apt-get dist-upgrade -y; then
  success "Full upgrade complete."
else
  warn "dist-upgrade had issues — continuing anyway."
fi

log "Removing unused packages..."
apt-get autoremove -y && apt-get autoclean -y
success "Cleanup complete."

# ==============================================================================
# 2. Flatpak
# ==============================================================================
section "📦 Flatpak — Updating Apps"

if command -v flatpak &>/dev/null; then
  log "Updating all Flatpak applications..."
  if flatpak update --noninteractive -y; then
    success "Flatpak apps updated."
  else
    warn "Flatpak update encountered issues — continuing."
  fi
else
  warn "Flatpak is not installed. Skipping."
fi

# ==============================================================================
# 3. Snap
# ==============================================================================
section "📦 Snap — Updating Apps"

if command -v snap &>/dev/null; then
  log "Refreshing all Snap packages..."
  if snap refresh; then
    success "Snap packages updated."
  else
    warn "Snap refresh encountered issues — continuing."
  fi
else
  warn "Snap is not installed. Skipping."
fi

# ==============================================================================
# 4. Reboot
# ==============================================================================
section "🔁 Rebooting System"

echo ""
warn "All updates complete. The system will reboot in ${REBOOT_DELAY} seconds."
warn "Press Ctrl+C to cancel the reboot."
echo ""

for ((i=REBOOT_DELAY; i>0; i--)); do
  echo -ne "${YELLOW}Rebooting in ${i}s...${RESET}\r"
  sleep 1
done

echo ""
log "Rebooting now at $(date)..."
reboot