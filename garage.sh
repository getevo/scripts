#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="garage"
DEFAULT_DATA_DIR="/data/garage"

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- prompt for settings ----------
echo ""
echo "Garage S3 Setup (Rust-based)"
echo "============================"
echo ""

if [[ -z "${GARAGE_S3_PORT:-}" ]]; then
  read -p "S3 API port [3900]: " GARAGE_S3_PORT
  GARAGE_S3_PORT="${GARAGE_S3_PORT:-3900}"
fi

if [[ -z "${GARAGE_WEB_PORT:-}" ]]; then
  read -p "Web/Admin port [3902]: " GARAGE_WEB_PORT
  GARAGE_WEB_PORT="${GARAGE_WEB_PORT:-3902}"
fi

if [[ -z "${GARAGE_RPC_PORT:-}" ]]; then
  read -p "RPC port [3901]: " GARAGE_RPC_PORT
  GARAGE_RPC_PORT="${GARAGE_RPC_PORT:-3901}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# Generate random secret for RPC
RPC_SECRET=$(openssl rand -hex 32)

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing Garage container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create directories ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p /etc/garage

# ---------- create garage config ----------
log "Creating Garage configuration..."
cat > /etc/garage/garage.toml <<EOF
metadata_dir = "/data/meta"
data_dir = "/data/blocks"
db_engine = "sqlite"

replication_factor = 1

[rpc]
bind_addr = "[::]:3901"
rpc_secret = "${RPC_SECRET}"

[s3_api]
s3_region = "garage"
api_bind_addr = "[::]:3900"
root_domain = ".s3.garage.localhost"

[s3_web]
bind_addr = "[::]:3902"
root_domain = ".web.garage.localhost"

[admin]
api_bind_addr = "[::]:3903"
EOF

# ---------- run garage container ----------
log "Starting Garage container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${GARAGE_S3_PORT}:3900" \
  -p "${GARAGE_RPC_PORT}:3901" \
  -p "${GARAGE_WEB_PORT}:3902" \
  -p 3903:3903 \
  -v "${DATA_DIR}:/data" \
  -v /etc/garage/garage.toml:/etc/garage.toml \
  dxflrs/garage:latest

# ---------- wait for garage to start ----------
log "Waiting for Garage to start..."
sleep 5

# ---------- get node id and configure ----------
log "Configuring Garage node..."
NODE_ID=$(docker exec "${CONTAINER_NAME}" garage node id 2>/dev/null | head -1 | cut -d'@' -f1 || echo "")

if [[ -n "${NODE_ID}" ]]; then
  # Configure the node with all capacity
  docker exec "${CONTAINER_NAME}" garage layout assign -z dc1 -c 1G "${NODE_ID}" 2>/dev/null || true
  docker exec "${CONTAINER_NAME}" garage layout apply --version 1 2>/dev/null || true
fi

# ---------- create default key ----------
log "Creating default API key..."
KEY_OUTPUT=$(docker exec "${CONTAINER_NAME}" garage key create default-key 2>/dev/null || echo "")
ACCESS_KEY=$(echo "${KEY_OUTPUT}" | grep -oP 'Key ID: \K[A-Z0-9]+' || echo "check-manually")
SECRET_KEY=$(echo "${KEY_OUTPUT}" | grep -oP 'Secret key: \K[a-f0-9]+' || echo "check-manually")

# ---------- get server ip ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  Garage Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "S3 API port: ${GARAGE_S3_PORT}"
  echo "RPC port: ${GARAGE_RPC_PORT}"
  echo "Web port: ${GARAGE_WEB_PORT}"
  echo "Admin port: 3903"
  echo "Data directory: ${DATA_DIR}"
  echo ""
  echo "Default API Key:"
  echo "  Access Key: ${ACCESS_KEY}"
  echo "  Secret Key: ${SECRET_KEY}"
  echo ""
  echo "S3 Endpoint:"
  echo "  http://${SERVER_IP}:${GARAGE_S3_PORT}"
  echo ""
  echo "Next steps:"
  echo "  1. Create bucket: docker exec ${CONTAINER_NAME} garage bucket create mybucket"
  echo "  2. Allow key: docker exec ${CONTAINER_NAME} garage bucket allow --read --write mybucket --key default-key"
  echo ""
  echo "Config: /etc/garage/garage.toml"
  echo ""
else
  echo "ERROR: Garage container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
