#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

WG_DIR="/etc/wireguard"
WG_INTERFACE="wg0"
WG_PORT="${WG_PORT:-51820}"

# ---------- check wireguard is installed ----------
if [[ ! -f "${WG_DIR}/${WG_INTERFACE}.conf" ]]; then
  echo "ERROR: WireGuard server not configured. Run wireguard.sh first."
  exit 1
fi

# ---------- get client name ----------
CLIENT_NAME="${1:-}"

if [[ -z "${CLIENT_NAME}" ]]; then
  echo ""
  read -p "Enter client name (e.g., phone, laptop): " CLIENT_NAME
fi

if [[ -z "${CLIENT_NAME}" ]]; then
  echo "ERROR: Client name cannot be empty"
  exit 1
fi

# Sanitize client name
CLIENT_NAME=$(echo "${CLIENT_NAME}" | tr -cd '[:alnum:]-_')

CLIENT_DIR="${WG_DIR}/clients"
CLIENT_FILE="${CLIENT_DIR}/${CLIENT_NAME}.conf"

if [[ -f "${CLIENT_FILE}" ]]; then
  echo "ERROR: Client '${CLIENT_NAME}' already exists"
  echo "Config: ${CLIENT_FILE}"
  exit 1
fi

# ---------- find next available IP ----------
log "Finding next available IP..."
USED_IPS=$(grep -h "AllowedIPs" "${WG_DIR}/${WG_INTERFACE}.conf" 2>/dev/null | grep -oE '10\.0\.0\.[0-9]+' || echo "")
NEXT_IP=2
for i in $(seq 2 254); do
  if ! echo "${USED_IPS}" | grep -q "10.0.0.${i}"; then
    NEXT_IP=$i
    break
  fi
done

CLIENT_IP="10.0.0.${NEXT_IP}"
log "Assigned IP: ${CLIENT_IP}"

# ---------- generate client keys ----------
log "Generating client keys..."
mkdir -p "${CLIENT_DIR}"
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "${CLIENT_PRIVATE_KEY}" | wg pubkey)

# ---------- get server info ----------
SERVER_PUBLIC_KEY=$(cat "${WG_DIR}/server_public.key")
SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

# ---------- create client config ----------
log "Creating client configuration..."
cat > "${CLIENT_FILE}" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/24
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${SERVER_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

chmod 600 "${CLIENT_FILE}"

# ---------- add peer to server config ----------
log "Adding peer to server configuration..."
cat >> "${WG_DIR}/${WG_INTERFACE}.conf" <<EOF

# Client: ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32
EOF

# ---------- reload wireguard ----------
log "Reloading WireGuard..."
wg syncconf "${WG_INTERFACE}" <(wg-quick strip "${WG_INTERFACE}")

log "Done."
echo ""
echo "=========================================="
echo "  WireGuard Client Created: ${CLIENT_NAME}"
echo "=========================================="
echo ""
echo "Client IP: ${CLIENT_IP}"
echo "Config file: ${CLIENT_FILE}"
echo ""
echo "=============== CONFIG ==============="
cat "${CLIENT_FILE}"
echo "======================================"
echo ""

# ---------- generate QR code if qrencode is available ----------
if command -v qrencode &>/dev/null; then
  echo ""
  echo "============== QR CODE ==============="
  qrencode -t ansiutf8 < "${CLIENT_FILE}"
  echo "======================================"
fi

echo ""
echo "Import this config into WireGuard client app."
echo ""
