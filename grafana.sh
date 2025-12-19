#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="grafana"
DEFAULT_DATA_DIR="/data/grafana"

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- prompt for settings ----------
echo ""
echo "Grafana Setup"
echo "============="
echo ""

if [[ -z "${GRAFANA_PORT:-}" ]]; then
  read -p "Port [3000]: " GRAFANA_PORT_INPUT
  GRAFANA_PORT="${GRAFANA_PORT_INPUT:-3000}"
else
  GRAFANA_PORT="${GRAFANA_PORT:-3000}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing Grafana container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"
chown -R 472:472 "${DATA_DIR}"

# ---------- run grafana container ----------
log "Starting Grafana container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${GRAFANA_PORT}:3000" \
  -v "${DATA_DIR}:/var/lib/grafana" \
  --add-host=host.docker.internal:host-gateway \
  grafana/grafana:latest

# ---------- wait for grafana to start ----------
log "Waiting for Grafana to start..."
sleep 5

# ---------- get server ip ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  Grafana Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
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
else
  echo "ERROR: Grafana container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
