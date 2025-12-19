#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="nats"
DEFAULT_DATA_DIR="/data/nats"

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- prompt for settings ----------
echo ""
echo "NATS Setup"
echo "=========="
echo ""

if [[ -z "${NATS_PORT:-}" ]]; then
  read -p "Client port [4222]: " NATS_PORT_INPUT
  NATS_PORT="${NATS_PORT_INPUT:-4222}"
else
  NATS_PORT="${NATS_PORT:-4222}"
fi

if [[ -z "${NATS_HTTP_PORT:-}" ]]; then
  read -p "HTTP monitoring port [8222]: " NATS_HTTP_PORT_INPUT
  NATS_HTTP_PORT="${NATS_HTTP_PORT_INPUT:-8222}"
else
  NATS_HTTP_PORT="${NATS_HTTP_PORT:-8222}"
fi

if [[ -z "${NATS_CLUSTER_PORT:-}" ]]; then
  read -p "Cluster port [6222]: " NATS_CLUSTER_PORT_INPUT
  NATS_CLUSTER_PORT="${NATS_CLUSTER_PORT_INPUT:-6222}"
else
  NATS_CLUSTER_PORT="${NATS_CLUSTER_PORT:-6222}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing NATS container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create directories ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p /etc/nats

# ---------- create nats config ----------
log "Creating NATS configuration..."
cat > /etc/nats/nats.conf <<EOF
# NATS Server Configuration

# Client port
port: 4222

# HTTP monitoring port
http_port: 8222

# Cluster port
cluster {
  port: 6222
}

# JetStream (persistence)
jetstream {
  store_dir: /data
  max_mem: 1G
  max_file: 10G
}

# Logging
debug: false
trace: false
logtime: true
EOF

# ---------- run nats container ----------
log "Starting NATS container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${NATS_PORT}:4222" \
  -p "${NATS_HTTP_PORT}:8222" \
  -p "${NATS_CLUSTER_PORT}:6222" \
  -v /etc/nats:/etc/nats \
  -v "${DATA_DIR}:/data" \
  nats:latest \
  -c /etc/nats/nats.conf

# ---------- wait for nats to start ----------
log "Waiting for NATS to start..."
sleep 5

# ---------- get server ip ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  NATS Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "Client port: ${NATS_PORT}"
  echo "HTTP monitoring: ${NATS_HTTP_PORT}"
  echo "Cluster port: ${NATS_CLUSTER_PORT}"
  echo "Data: ${DATA_DIR}"
  echo ""
  echo "Connect:"
  echo "  nats://${SERVER_IP}:${NATS_PORT}"
  echo ""
  echo "Monitoring:"
  echo "  http://${SERVER_IP}:${NATS_HTTP_PORT}"
  echo ""
  echo "Config: /etc/nats/nats.conf"
  echo ""
else
  echo "ERROR: NATS container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
