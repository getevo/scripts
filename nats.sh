#!/usr/bin/env bash
#
# nats.sh - Install NATS messaging server in Docker
#
# Usage:
#   sudo ./nats.sh                     # Interactive mode
#   sudo ./nats.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   NATS_PORT          - Client port (default: 4222)
#   NATS_HTTP_PORT     - HTTP monitoring port (default: 8222)
#   NATS_CLUSTER_PORT  - Cluster port (default: 6222)
#   DATA_DIR           - Data directory (default: /data/nats)
#   NATS_VERSION       - Image version (default: 2.10)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="nats"
DEFAULT_DATA_DIR="/data/nats"
NATS_PORT="${NATS_PORT:-4222}"
NATS_HTTP_PORT="${NATS_HTTP_PORT:-8222}"
NATS_CLUSTER_PORT="${NATS_CLUSTER_PORT:-6222}"
NATS_VERSION="${NATS_VERSION:-2.10}"

# ---------- Helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

wait_for_port() {
  local port="$1"
  local max_attempts="${2:-30}"
  local attempt=1
  while [[ $attempt -le $max_attempts ]]; do
    if timeout 1 bash -c "echo >/dev/tcp/localhost/${port}" 2>/dev/null; then
      return 0
    fi
    sleep 2
    ((attempt++))
  done
  return 1
}

# ---------- Root check ----------
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- Uninstall mode ----------
if [[ "${1:-}" == "--uninstall" ]]; then
  log "Uninstalling NATS..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  read -p "Remove config /etc/nats? [y/N]: " REMOVE_CONFIG
  if [[ "${REMOVE_CONFIG}" =~ ^[Yy]$ ]]; then
    rm -rf /etc/nats
    log "Config removed"
  fi
  log "NATS uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "NATS Setup"
echo "=========="
echo ""

if [[ -z "${NATS_PORT:-}" ]] || [[ "${NATS_PORT}" == "4222" ]]; then
  read -p "Client port [4222]: " NATS_PORT_INPUT
  NATS_PORT="${NATS_PORT_INPUT:-4222}"
fi

if [[ -z "${NATS_HTTP_PORT:-}" ]] || [[ "${NATS_HTTP_PORT}" == "8222" ]]; then
  read -p "HTTP monitoring port [8222]: " NATS_HTTP_PORT_INPUT
  NATS_HTTP_PORT="${NATS_HTTP_PORT_INPUT:-8222}"
fi

if [[ -z "${NATS_CLUSTER_PORT:-}" ]] || [[ "${NATS_CLUSTER_PORT}" == "6222" ]]; then
  read -p "Cluster port [6222]: " NATS_CLUSTER_PORT_INPUT
  NATS_CLUSTER_PORT="${NATS_CLUSTER_PORT_INPUT:-6222}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing NATS container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create directories ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p /etc/nats

# ---------- Create NATS config ----------
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

# ---------- Run container ----------
log "Starting NATS ${NATS_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${NATS_PORT}:4222" \
  -p "${NATS_HTTP_PORT}:8222" \
  -p "${NATS_CLUSTER_PORT}:6222" \
  -v /etc/nats:/etc/nats \
  -v "${DATA_DIR}:/data" \
  --health-cmd="wget -q --spider http://localhost:8222/healthz || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  nats:${NATS_VERSION} \
  -c /etc/nats/nats.conf

# ---------- Wait for healthy ----------
log "Waiting for NATS to be ready..."
if ! wait_for_port "${NATS_PORT}" 30; then
  echo "ERROR: NATS failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  NATS Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${NATS_VERSION}"
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
echo "Uninstall:"
echo "  sudo ./nats.sh --uninstall"
echo ""
