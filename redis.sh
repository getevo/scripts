#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="redis"
DATA_DIR="/data/redis"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-$(openssl rand -base64 16)}"

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing Redis container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- run redis container ----------
log "Starting Redis container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${REDIS_PORT}:6379" \
  -v "${DATA_DIR}:/data" \
  redis:7 \
  redis-server --appendonly yes --requirepass "${REDIS_PASSWORD}"

# ---------- wait for redis to start ----------
log "Waiting for Redis to start..."
sleep 5

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  Redis Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "Port: ${REDIS_PORT}"
  echo "Data directory: ${DATA_DIR}"
  echo "Password: ${REDIS_PASSWORD}"
  echo ""
  echo "Connect:"
  echo "  docker exec -it ${CONTAINER_NAME} redis-cli -a '${REDIS_PASSWORD}'"
  echo ""
  echo "SAVE THE PASSWORD!"
  echo ""
else
  echo "ERROR: Redis container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
