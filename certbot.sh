#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- install certbot ----------
log "Installing Certbot..."
apt-get update -y
apt-get install -y certbot

# ---------- install nginx plugin if nginx is installed ----------
if need_cmd nginx; then
  log "Installing Certbot Nginx plugin..."
  apt-get install -y python3-certbot-nginx
fi

# ---------- install apache plugin if apache is installed ----------
if need_cmd apache2; then
  log "Installing Certbot Apache plugin..."
  apt-get install -y python3-certbot-apache
fi

# ---------- setup auto-renewal ----------
log "Setting up auto-renewal..."
systemctl enable certbot.timer
systemctl start certbot.timer

log "Done."
echo ""
echo "=========================================="
echo "  Certbot Installation Complete!"
echo "=========================================="
echo ""
echo "Version: $(certbot --version)"
echo ""
echo "Get certificate (Nginx):"
echo "  certbot --nginx -d example.com -d www.example.com"
echo ""
echo "Get certificate (standalone):"
echo "  certbot certonly --standalone -d example.com"
echo ""
echo "Test renewal:"
echo "  certbot renew --dry-run"
echo ""
echo "List certificates:"
echo "  certbot certificates"
echo ""
