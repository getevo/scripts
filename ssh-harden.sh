#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.backup.$(date +%Y%m%d%H%M%S)"

# ---------- backup original config ----------
log "Backing up SSH config to ${BACKUP_FILE}..."
cp "${SSHD_CONFIG}" "${BACKUP_FILE}"

# ---------- harden ssh config ----------
log "Hardening SSH configuration..."

# Create hardened config
cat > /etc/ssh/sshd_config.d/99-hardened.conf <<'EOF'
# Disable root login
PermitRootLogin no

# Disable password authentication (use keys only)
PasswordAuthentication no

# Disable empty passwords
PermitEmptyPasswords no

# Disable X11 forwarding
X11Forwarding no

# Set max auth tries
MaxAuthTries 3

# Set login grace time
LoginGraceTime 60

# Disable TCP forwarding
AllowTcpForwarding no

# Disable agent forwarding
AllowAgentForwarding no

# Use strong ciphers only
Ciphers aes256-gcm@openssh.com,chacha20-poly1305@openssh.com,aes256-ctr

# Use strong MACs
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# Use strong key exchange
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512

# Log level
LogLevel VERBOSE
EOF

# ---------- test config ----------
log "Testing SSH configuration..."
if ! sshd -t; then
  log "ERROR: SSH config test failed. Restoring backup..."
  cp "${BACKUP_FILE}" "${SSHD_CONFIG}"
  rm -f /etc/ssh/sshd_config.d/99-hardened.conf
  exit 1
fi

# ---------- restart ssh ----------
log "Restarting SSH service..."
systemctl restart sshd

log "Done."
echo ""
echo "=========================================="
echo "  SSH Hardening Complete!"
echo "=========================================="
echo ""
echo "Changes applied:"
echo " - Root login disabled"
echo " - Password auth disabled (keys only!)"
echo " - Max auth tries: 3"
echo " - X11 forwarding disabled"
echo " - Strong ciphers only"
echo ""
echo "Backup: ${BACKUP_FILE}"
echo "Config: /etc/ssh/sshd_config.d/99-hardened.conf"
echo ""
echo "WARNING: Ensure you have SSH key access before logging out!"
echo ""
