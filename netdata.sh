#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

NETDATA_PORT="${NETDATA_PORT:-19999}"

# ---------- install netdata ----------
log "Installing Netdata..."
curl -fsSL https://get.netdata.cloud/kickstart.sh > /tmp/netdata-kickstart.sh
bash /tmp/netdata-kickstart.sh --stable-channel --disable-telemetry --non-interactive
rm /tmp/netdata-kickstart.sh

# ---------- configure firewall ----------
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
  log "Allowing Netdata through UFW..."
  ufw allow ${NETDATA_PORT}/tcp
fi

# ---------- get server ip ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  Netdata Installation Complete!"
echo "=========================================="
echo ""
echo "Access dashboard:"
echo "  http://${SERVER_IP}:${NETDATA_PORT}"
echo ""
echo "Config: /etc/netdata/netdata.conf"
echo ""
echo "Commands:"
echo "  systemctl status netdata"
echo "  systemctl restart netdata"
echo ""
