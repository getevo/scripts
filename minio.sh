#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="minio"
DEFAULT_DATA_DIR="/data/minio"

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- prompt for settings ----------
echo ""
echo "MinIO Setup"
echo "==========="
echo ""

if [[ -z "${MINIO_ROOT_USER:-}" ]]; then
  read -p "Root user (access key) [minioadmin]: " MINIO_ROOT_USER
  MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
fi

if [[ -z "${MINIO_ROOT_PASSWORD:-}" ]]; then
  while true; do
    read -s -p "Root password (secret key) [minioadmin]: " MINIO_ROOT_PASSWORD
    echo ""
    MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"
    if [[ ${#MINIO_ROOT_PASSWORD} -lt 8 ]]; then
      echo "Password must be at least 8 characters. Please try again."
    else
      break
    fi
  done
fi

if [[ -z "${MINIO_API_PORT:-}" ]]; then
  read -p "API port [9000]: " MINIO_API_PORT
  MINIO_API_PORT="${MINIO_API_PORT:-9000}"
fi

if [[ -z "${MINIO_CONSOLE_PORT:-}" ]]; then
  read -p "Console port [9001]: " MINIO_CONSOLE_PORT
  MINIO_CONSOLE_PORT="${MINIO_CONSOLE_PORT:-9001}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing MinIO container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- run minio container ----------
log "Starting MinIO container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${MINIO_API_PORT}:9000" \
  -p "${MINIO_CONSOLE_PORT}:9001" \
  -v "${DATA_DIR}:/data" \
  -e MINIO_ROOT_USER="${MINIO_ROOT_USER}" \
  -e MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD}" \
  minio/minio:latest server /data --console-address ":9001"

# ---------- wait for minio to start ----------
log "Waiting for MinIO to start..."
sleep 5

# ---------- get server ip ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  MinIO Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "API port: ${MINIO_API_PORT}"
  echo "Console port: ${MINIO_CONSOLE_PORT}"
  echo "Data directory: ${DATA_DIR}"
  echo ""
  echo "Credentials:"
  echo "  Access Key: ${MINIO_ROOT_USER}"
  echo "  Secret Key: (hidden)"
  echo ""
  echo "Console UI:"
  echo "  http://${SERVER_IP}:${MINIO_CONSOLE_PORT}"
  echo ""
  echo "S3 Endpoint:"
  echo "  http://${SERVER_IP}:${MINIO_API_PORT}"
  echo ""
else
  echo "ERROR: MinIO container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
