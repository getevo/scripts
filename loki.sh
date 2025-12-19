#!/usr/bin/env bash
#
# loki.sh - Install Loki log aggregation in Docker
#
# Usage:
#   sudo ./loki.sh                     # Interactive mode
#   sudo ./loki.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   LOKI_PORT     - Port to expose (default: 3100)
#   DATA_DIR      - Data directory (default: /data/loki)
#   LOKI_VERSION  - Image version (default: 2.9.4)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="loki"
DEFAULT_DATA_DIR="/data/loki"
LOKI_PORT="${LOKI_PORT:-3100}"
LOKI_VERSION="${LOKI_VERSION:-2.9.4}"

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
  log "Uninstalling Loki..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  read -p "Remove config /etc/loki? [y/N]: " REMOVE_CONFIG
  if [[ "${REMOVE_CONFIG}" =~ ^[Yy]$ ]]; then
    rm -rf /etc/loki
    log "Config removed"
  fi
  log "Loki uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "Loki Setup"
echo "=========="
echo ""

if [[ -z "${LOKI_PORT:-}" ]] || [[ "${LOKI_PORT}" == "3100" ]]; then
  read -p "Port [3100]: " LOKI_PORT_INPUT
  LOKI_PORT="${LOKI_PORT_INPUT:-3100}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing Loki container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create directories ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p /etc/loki

# ---------- Create Loki config ----------
log "Creating Loki configuration..."
cat > /etc/loki/config.yml <<'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
    shared_store: filesystem

limits_config:
  retention_period: 168h
EOF

# ---------- Run container ----------
log "Starting Loki ${LOKI_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${LOKI_PORT}:3100" \
  -v /etc/loki:/etc/loki \
  -v "${DATA_DIR}:/loki" \
  --health-cmd="wget -q --spider http://localhost:3100/ready || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  grafana/loki:${LOKI_VERSION} \
  -config.file=/etc/loki/config.yml

# ---------- Wait for healthy ----------
log "Waiting for Loki to be ready..."
if ! wait_for_port "${LOKI_PORT}" 30; then
  echo "ERROR: Loki failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  Loki Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${LOKI_VERSION}"
echo "Port: ${LOKI_PORT}"
echo "Data: ${DATA_DIR}"
echo ""
echo "API endpoint:"
echo "  http://${SERVER_IP}:${LOKI_PORT}"
echo ""
echo "Add as Grafana datasource:"
echo "  URL: http://loki:3100 (or http://${SERVER_IP}:${LOKI_PORT})"
echo ""
echo "Config: /etc/loki/config.yml"
echo ""
echo "Uninstall:"
echo "  sudo ./loki.sh --uninstall"
echo ""
