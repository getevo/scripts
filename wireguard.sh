#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

WG_DIR="/etc/wireguard"
WG_PORT="${WG_PORT:-51820}"

# ---------- install wireguard ----------
log "Installing WireGuard..."
apt-get update -y
apt-get install -y wireguard wireguard-tools qrencode

# ---------- enable ip forwarding ----------
log "Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

# ---------- generate server keys ----------
log "Generating server keys..."
mkdir -p "${WG_DIR}"
chmod 700 "${WG_DIR}"

if [[ ! -f "${WG_DIR}/server_private.key" ]]; then
  wg genkey | tee "${WG_DIR}/server_private.key" | wg pubkey > "${WG_DIR}/server_public.key"
  chmod 600 "${WG_DIR}/server_private.key"
fi

SERVER_PRIVATE_KEY=$(cat "${WG_DIR}/server_private.key")
SERVER_PUBLIC_KEY=$(cat "${WG_DIR}/server_public.key")

# ---------- detect main interface ----------
MAIN_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

# ---------- create server config ----------
log "Creating server configuration..."
cat > "${WG_DIR}/wg0.conf" <<EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_PRIVATE_KEY}

# NAT
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${MAIN_INTERFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${MAIN_INTERFACE} -j MASQUERADE

# Add peers below:
# [Peer]
# PublicKey = <client_public_key>
# AllowedIPs = 10.0.0.2/32
EOF

chmod 600 "${WG_DIR}/wg0.conf"

# ---------- enable and start wireguard ----------
log "Enabling WireGuard..."
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# ---------- configure firewall ----------
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
  log "Allowing WireGuard through UFW..."
  ufw allow ${WG_PORT}/udp
fi

log "Done."
echo ""
echo "=========================================="
echo "  WireGuard Installation Complete!"
echo "=========================================="
echo ""
echo "Server Public Key: ${SERVER_PUBLIC_KEY}"
echo "Server Port: ${WG_PORT}"
echo "VPN Subnet: 10.0.0.0/24"
echo ""
echo "Config: ${WG_DIR}/wg0.conf"
echo ""
echo "Add client peer to config:"
echo "  [Peer]"
echo "  PublicKey = <client_public_key>"
echo "  AllowedIPs = 10.0.0.2/32"
echo ""
echo "Commands:"
echo "  wg show                    # Show status"
echo "  systemctl restart wg-quick@wg0"
echo ""
