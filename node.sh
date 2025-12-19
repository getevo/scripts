#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# Default Node.js version
DEFAULT_VERSION=24

# ---------- get version ----------
NODE_MAJOR="${1:-}"

if [[ -z "${NODE_MAJOR}" ]]; then
  echo ""
  echo "Available LTS versions: 18, 20, 22, 24"
  read -p "Enter Node.js major version [${DEFAULT_VERSION}]: " NODE_MAJOR
  NODE_MAJOR="${NODE_MAJOR:-${DEFAULT_VERSION}}"
fi

# Validate version is a number
if ! [[ "${NODE_MAJOR}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Version must be a number (e.g., 18, 20, 22, 24)"
  exit 1
fi

log "Installing Node.js version: ${NODE_MAJOR}.x"

# ---------- check if already installed ----------
if need_cmd node; then
  CURRENT_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
  if [[ "${CURRENT_VERSION}" -eq "${NODE_MAJOR}" ]]; then
    log "Node.js ${NODE_MAJOR} already installed: $(node -v)"
    log "npm: $(npm -v)"
    exit 0
  fi
  log "Node.js found: $(node -v), will install v${NODE_MAJOR}"
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
