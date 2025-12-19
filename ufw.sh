#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- install ufw ----------
log "Installing UFW..."
apt-get update -y
apt-get install -y ufw

# ---------- configure default policies ----------
log "Configuring default policies..."
ufw default deny incoming
ufw default allow outgoing

# ---------- allow ssh ----------
log "Allowing SSH (port 22)..."
ufw allow ssh

# ---------- allow common ports ----------
log "Allowing HTTP (80) and HTTPS (443)..."
ufw allow http
ufw allow https

# ---------- enable ufw ----------
log "Enabling UFW..."
echo "y" | ufw enable

log "Done."
echo ""
echo "=========================================="
echo "  UFW Firewall Configuration Complete!"
echo "=========================================="
echo ""
ufw status verbose
echo ""
echo "Common commands:"
echo "  ufw allow 8080           # Allow port"
echo "  ufw deny 3306            # Deny port"
echo "  ufw delete allow 8080    # Remove rule"
echo "  ufw status numbered      # List rules with numbers"
echo "  ufw delete 3             # Delete rule by number"
echo ""
