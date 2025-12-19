#!/usr/bin/env bash
#
# grafana.sh - Install Grafana in Docker
#
# Usage:
#   sudo ./grafana.sh                     # Interactive mode
#   sudo ./grafana.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   GRAFANA_PORT     - Port to expose (default: 3000)
#   DATA_DIR         - Data directory (default: /data/grafana)
#   GRAFANA_VERSION  - Image version (default: 11.3.0)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="grafana"
DEFAULT_DATA_DIR="/data/grafana"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
GRAFANA_VERSION="${GRAFANA_VERSION:-11.3.0}"

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
  log "Uninstalling Grafana..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  log "Grafana uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "Grafana Setup"
echo "============="
echo ""

if [[ -z "${GRAFANA_PORT:-}" ]] || [[ "${GRAFANA_PORT}" == "3000" ]]; then
  read -p "Port [3000]: " GRAFANA_PORT_INPUT
  GRAFANA_PORT="${GRAFANA_PORT_INPUT:-3000}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing Grafana container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"
chown -R 472:472 "${DATA_DIR}"

# ---------- Run container ----------
log "Starting Grafana ${GRAFANA_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${GRAFANA_PORT}:3000" \
  -v "${DATA_DIR}:/var/lib/grafana" \
  --add-host=host.docker.internal:host-gateway \
  --health-cmd="wget -q --spider http://localhost:3000/api/health || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  grafana/grafana:${GRAFANA_VERSION}

# ---------- Wait for healthy ----------
log "Waiting for Grafana to be ready..."
if ! wait_for_port "${GRAFANA_PORT}" 30; then
  echo "ERROR: Grafana failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  Grafana Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${GRAFANA_VERSION}"
echo "Port: ${GRAFANA_PORT}"
echo "Data: ${DATA_DIR}"
echo ""
echo "Access:"
echo "  http://${SERVER_IP}:${GRAFANA_PORT}"
echo ""
echo "Default credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Change password on first login!"
echo ""
echo "Uninstall:"
echo "  sudo ./grafana.sh --uninstall"
echo ""
