#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# This script should NOT run as root
if [[ "${EUID}" -eq 0 ]]; then
  echo "Do not run as root. Run as normal user: ./$0"
  exit 1
fi

# ---------- check if already installed ----------
if need_cmd rustc; then
  log "Rust already installed: $(rustc --version)"
  log "Cargo: $(cargo --version)"
  exit 0
fi

# ---------- install prerequisites ----------
log "Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends curl build-essential

# ---------- install rustup ----------
log "Installing Rust via rustup..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# ---------- source cargo env ----------
source "$HOME/.cargo/env"

log "Done."
echo ""
echo "=========================================="
echo "  Rust Installation Complete!"
echo "=========================================="
echo ""
echo "Rust: $(rustc --version)"
echo "Cargo: $(cargo --version)"
echo ""
echo "Notes:"
echo " - Run 'source ~/.cargo/env' or log out and back in"
echo " - Update with: rustup update"
echo ""
