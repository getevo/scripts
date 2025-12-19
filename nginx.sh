#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- install nginx ----------
log "Installing Nginx..."
apt-get update -y
apt-get install -y nginx

# ---------- enable and start nginx ----------
log "Enabling and starting Nginx..."
systemctl enable nginx
systemctl start nginx

# ---------- configure firewall if ufw is active ----------
if need_cmd ufw && ufw status | grep -q "active"; then
  log "Allowing Nginx through UFW..."
  ufw allow 'Nginx Full'
fi

log "Done."
echo ""
echo "=========================================="
echo "  Nginx Installation Complete!"
echo "=========================================="
echo ""
echo "Version: $(nginx -v 2>&1)"
echo "Status: $(systemctl is-active nginx)"
echo ""
echo "Config: /etc/nginx/nginx.conf"
echo "Sites: /etc/nginx/sites-available/"
echo "Logs: /var/log/nginx/"
echo ""
echo "Commands:"
echo "  sudo nginx -t          # Test config"
echo "  sudo systemctl reload nginx"
echo ""
