#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- install fail2ban ----------
log "Installing Fail2ban..."
apt-get update -y
apt-get install -y fail2ban

# ---------- create local config ----------
log "Creating Fail2ban configuration..."
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
# Ban hosts for 1 hour
bantime = 3600

# Find failures within 10 minutes
findtime = 600

# Allow 5 failures before ban
maxretry = 5

# Ignore localhost
ignoreip = 127.0.0.1/8 ::1

# Use systemd backend
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF

# ---------- enable and start fail2ban ----------
log "Enabling and starting Fail2ban..."
systemctl enable fail2ban
systemctl restart fail2ban

# ---------- wait for service to start ----------
sleep 2

log "Done."
echo ""
echo "=========================================="
echo "  Fail2ban Installation Complete!"
echo "=========================================="
echo ""
echo "Status:"
fail2ban-client status
echo ""
echo "SSH jail status:"
fail2ban-client status sshd 2>/dev/null || echo "  (starting...)"
echo ""
echo "Config: /etc/fail2ban/jail.local"
echo ""
echo "Commands:"
echo "  fail2ban-client status sshd    # Check SSH jail"
echo "  fail2ban-client unban <IP>     # Unban IP"
echo ""
