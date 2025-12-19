#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# Node.js LTS version (22.x as of 2024)
NODE_MAJOR=22

# ---------- check if already installed ----------
if need_cmd node; then
  CURRENT_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
  if [[ "${CURRENT_VERSION}" -ge "${NODE_MAJOR}" ]]; then
    log "Node.js ${NODE_MAJOR}+ already installed: $(node -v)"
    log "npm: $(npm -v)"
    exit 0
  fi
  log "Node.js found but version $(node -v) is older than v${NODE_MAJOR}"
fi

# ---------- install prerequisites ----------
log "Installing prerequisites..."
apt-get update -y
apt-get install -y --no-install-recommends ca-certificates curl gnupg

# ---------- add nodesource repository ----------
log "Adding NodeSource repository for Node.js ${NODE_MAJOR}..."
curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -

# ---------- install node ----------
log "Installing Node.js ${NODE_MAJOR}..."
apt-get install -y nodejs

log "Done."
echo ""
echo "=========================================="
echo "  Node.js Installation Complete!"
echo "=========================================="
echo ""
echo "Node.js: $(node -v)"
echo "npm: $(npm -v)"
echo ""
