#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="qdrant"
DEFAULT_DATA_DIR="/data/qdrant"

# ---------- prompt for configuration ----------
echo ""
echo "Qdrant Setup"
echo "============"
echo ""

if [[ -z "${QDRANT_API_KEY:-}" ]]; then
  while true; do
    read -s -p "API Key (for authentication): " QDRANT_API_KEY
    echo ""
    if [[ -z "${QDRANT_API_KEY}" ]]; then
      echo "API Key cannot be empty. Please try again."
    else
      read -s -p "Confirm API Key: " QDRANT_API_KEY_CONFIRM
      echo ""
      if [[ "${QDRANT_API_KEY}" != "${QDRANT_API_KEY_CONFIRM}" ]]; then
        echo "API Keys do not match. Please try again."
      else
        break
      fi
    fi
  done
fi

if [[ -z "${QDRANT_HTTP_PORT:-}" ]] || [[ "${QDRANT_HTTP_PORT}" == "6333" ]]; then
  read -p "HTTP port [6333]: " QDRANT_HTTP_PORT_INPUT
  QDRANT_HTTP_PORT="${QDRANT_HTTP_PORT_INPUT:-6333}"
fi

if [[ -z "${QDRANT_GRPC_PORT:-}" ]] || [[ "${QDRANT_GRPC_PORT}" == "6334" ]]; then
  read -p "gRPC port [6334]: " QDRANT_GRPC_PORT_INPUT
  QDRANT_GRPC_PORT="${QDRANT_GRPC_PORT_INPUT:-6334}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing Qdrant container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}/storage"

# ---------- run qdrant container ----------
log "Starting Qdrant container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${QDRANT_HTTP_PORT}:6333" \
  -p "${QDRANT_GRPC_PORT}:6334" \
  -v "${DATA_DIR}/storage:/qdrant/storage" \
  -e QDRANT__SERVICE__API_KEY="${QDRANT_API_KEY}" \
  qdrant/qdrant:latest

# ---------- wait for qdrant to start ----------
log "Waiting for Qdrant to start..."
sleep 5

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  Qdrant Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "HTTP port: ${QDRANT_HTTP_PORT}"
  echo "gRPC port: ${QDRANT_GRPC_PORT}"
  echo "Data directory: ${DATA_DIR}"
  echo "API Key: (hidden)"
  echo ""
  echo "Dashboard:"
  echo "  http://localhost:${QDRANT_HTTP_PORT}/dashboard"
  echo ""
  echo "Test connection:"
  echo "  curl -H 'api-key: <your-api-key>' http://localhost:${QDRANT_HTTP_PORT}/collections"
  echo ""
else
  echo "ERROR: Qdrant container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
