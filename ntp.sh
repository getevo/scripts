#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- install and configure systemd-timesyncd ----------
log "Configuring NTP time synchronization..."

# Enable NTP
timedatectl set-ntp true

# Configure timesyncd with multiple NTP servers
log "Configuring NTP servers..."
mkdir -p /etc/systemd/timesyncd.conf.d/
cat > /etc/systemd/timesyncd.conf.d/custom.conf <<'EOF'
[Time]
NTP=time.cloudflare.com time.google.com
FallbackNTP=pool.ntp.org ntp.ubuntu.com
EOF

# Restart timesyncd
log "Restarting timesyncd..."
systemctl restart systemd-timesyncd

# Wait for sync
sleep 2

log "Done."
echo ""
echo "=========================================="
echo "  NTP Configuration Complete!"
echo "=========================================="
echo ""
timedatectl
echo ""
echo "NTP Servers:"
echo " - time.cloudflare.com"
echo " - time.google.com"
echo " - pool.ntp.org (fallback)"
echo ""
echo "Check sync status: timedatectl timesync-status"
echo ""
