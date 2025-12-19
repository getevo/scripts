#!/usr/bin/env bash
#
# wireguard.sh - Install and configure WireGuard VPN server
#
# Usage:
#   sudo ./wireguard.sh                     # Interactive mode
#   sudo ./wireguard.sh --uninstall         # Remove WireGuard
#
# Environment Variables:
#   WG_PORT      - UDP port (default: 51820)
#   WG_SUBNET    - VPN subnet (default: 10.0.0.0/24)
#   WG_ADDRESS   - Server VPN address (default: 10.0.0.1)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
WG_DIR="/etc/wireguard"
WG_PORT="${WG_PORT:-51820}"
WG_SUBNET="${WG_SUBNET:-10.0.0.0/24}"
WG_ADDRESS="${WG_ADDRESS:-10.0.0.1}"

# ---------- Helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---------- Root check ----------
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- Uninstall mode ----------
if [[ "${1:-}" == "--uninstall" ]]; then
  log "Uninstalling WireGuard..."
  systemctl stop wg-quick@wg0 2>/dev/null || true
  systemctl disable wg-quick@wg0 2>/dev/null || true
  apt-get remove -y wireguard wireguard-tools 2>/dev/null || true
  read -p "Remove WireGuard config and keys from ${WG_DIR}? [y/N]: " REMOVE_CONFIG
  if [[ "${REMOVE_CONFIG}" =~ ^[Yy]$ ]]; then
    rm -rf "${WG_DIR}"
    log "Config and keys removed"
  fi
  log "WireGuard uninstalled"
  exit 0
fi

# ---------- Prompt for configuration ----------
echo ""
echo "WireGuard Setup"
echo "==============="
echo ""

if [[ -z "${WG_PORT:-}" ]] || [[ "${WG_PORT}" == "51820" ]]; then
  read -p "UDP Port [51820]: " WG_PORT_INPUT
  WG_PORT="${WG_PORT_INPUT:-51820}"
fi

if [[ -z "${WG_SUBNET:-}" ]] || [[ "${WG_SUBNET}" == "10.0.0.0/24" ]]; then
  read -p "VPN Subnet [10.0.0.0/24]: " WG_SUBNET_INPUT
  WG_SUBNET="${WG_SUBNET_INPUT:-10.0.0.0/24}"
fi

if [[ -z "${WG_ADDRESS:-}" ]] || [[ "${WG_ADDRESS}" == "10.0.0.1" ]]; then
  # Extract default from subnet (e.g., 10.0.0.0/24 -> 10.0.0.1)
  DEFAULT_ADDRESS=$(echo "${WG_SUBNET}" | sed 's|\.0/|.1/|' | cut -d'/' -f1)
  read -p "Server VPN Address [${DEFAULT_ADDRESS}]: " WG_ADDRESS_INPUT
  WG_ADDRESS="${WG_ADDRESS_INPUT:-${DEFAULT_ADDRESS}}"
fi

# Extract subnet mask
SUBNET_MASK=$(echo "${WG_SUBNET}" | cut -d'/' -f2)

# ---------- Install WireGuard ----------
log "Installing WireGuard..."
apt-get update -y
apt-get install -y wireguard wireguard-tools qrencode

# ---------- Enable IP forwarding ----------
log "Enabling IP forwarding..."
cat > /etc/sysctl.d/99-wireguard.conf <<EOF
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
sysctl -p /etc/sysctl.d/99-wireguard.conf

# ---------- Generate server keys ----------
log "Generating server keys..."
mkdir -p "${WG_DIR}"
chmod 700 "${WG_DIR}"

if [[ ! -f "${WG_DIR}/server_private.key" ]]; then
  wg genkey | tee "${WG_DIR}/server_private.key" | wg pubkey > "${WG_DIR}/server_public.key"
  chmod 600 "${WG_DIR}/server_private.key"
fi

SERVER_PRIVATE_KEY=$(cat "${WG_DIR}/server_private.key")
SERVER_PUBLIC_KEY=$(cat "${WG_DIR}/server_public.key")

# ---------- Detect main interface ----------
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

# ---------- Create server config ----------
log "Creating server configuration..."
cat > "${WG_DIR}/wg0.conf" <<EOF
[Interface]
Address = ${WG_ADDRESS}/${SUBNET_MASK}
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}

# NAT
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${MAIN_INTERFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${MAIN_INTERFACE} -j MASQUERADE

# Add peers below using wireguard-client.sh or manually:
# [Peer]
# PublicKey = <client_public_key>
# AllowedIPs = 10.0.0.2/32
EOF

chmod 600 "${WG_DIR}/wg0.conf"

# ---------- Enable and start WireGuard ----------
log "Enabling WireGuard..."
systemctl enable wg-quick@wg0
systemctl restart wg-quick@wg0

# ---------- Configure firewall ----------
if need_cmd ufw && ufw status | grep -q "active"; then
  log "Allowing WireGuard through UFW..."
  ufw allow ${WG_PORT}/udp
fi

# ---------- Get server public IP ----------
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  WireGuard Installation Complete!"
echo "=========================================="
echo ""
echo "Server Public IP: ${SERVER_IP}"
echo "Server Public Key: ${SERVER_PUBLIC_KEY}"
echo "Server Port: ${WG_PORT}"
echo "VPN Subnet: ${WG_SUBNET}"
echo "Server VPN Address: ${WG_ADDRESS}"
echo ""
echo "Config: ${WG_DIR}/wg0.conf"
echo ""
echo "Add clients:"
echo "  sudo ./wireguard-client.sh <client-name>"
echo ""
echo "Commands:"
echo "  wg show                         # Show status"
echo "  systemctl restart wg-quick@wg0  # Restart"
echo ""
echo "Uninstall:"
echo "  sudo ./wireguard.sh --uninstall"
echo ""
