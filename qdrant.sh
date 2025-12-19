#!/usr/bin/env bash
#
# qdrant.sh - Install Qdrant vector database in Docker
#
# Usage:
#   sudo ./qdrant.sh                     # Interactive mode
#   sudo ./qdrant.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   QDRANT_API_KEY    - API key for authentication (required)
#   QDRANT_HTTP_PORT  - HTTP port (default: 6333)
#   QDRANT_GRPC_PORT  - gRPC port (default: 6334)
#   DATA_DIR          - Data directory (default: /data/qdrant)
#   QDRANT_VERSION    - Image version (default: v1.12.4)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="qdrant"
DEFAULT_DATA_DIR="/data/qdrant"
QDRANT_HTTP_PORT="${QDRANT_HTTP_PORT:-6333}"
QDRANT_GRPC_PORT="${QDRANT_GRPC_PORT:-6334}"
QDRANT_VERSION="${QDRANT_VERSION:-v1.12.4}"

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

prompt_password() {
  local var_name="$1"
  local prompt_text="${2:-Password}"
  while true; do
    read -s -p "${prompt_text}: " password
    echo ""
    if [[ -z "${password}" ]]; then
      echo "API Key cannot be empty. Please try again."
      continue
    fi
    read -s -p "Confirm ${prompt_text}: " password_confirm
    echo ""
    if [[ "${password}" != "${password_confirm}" ]]; then
      echo "API Keys do not match. Please try again."
      continue
    fi
    eval "${var_name}='${password}'"
    break
  done
}

# ---------- Root check ----------
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- Uninstall mode ----------
if [[ "${1:-}" == "--uninstall" ]]; then
  log "Uninstalling Qdrant..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  log "Qdrant uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "Qdrant Setup"
echo "============"
echo ""

if [[ -z "${QDRANT_API_KEY:-}" ]]; then
  prompt_password QDRANT_API_KEY "API Key (for authentication)"
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

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing Qdrant container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}/storage"

# ---------- Run container ----------
log "Starting Qdrant ${QDRANT_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${QDRANT_HTTP_PORT}:6333" \
  -p "${QDRANT_GRPC_PORT}:6334" \
  -v "${DATA_DIR}/storage:/qdrant/storage" \
  -e QDRANT__SERVICE__API_KEY="${QDRANT_API_KEY}" \
  --health-cmd="wget -q --spider http://localhost:6333/healthz || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  qdrant/qdrant:${QDRANT_VERSION}

# ---------- Wait for healthy ----------
log "Waiting for Qdrant to be ready..."
if ! wait_for_port "${QDRANT_HTTP_PORT}" 30; then
  echo "ERROR: Qdrant failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  Qdrant Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${QDRANT_VERSION}"
echo "HTTP port: ${QDRANT_HTTP_PORT}"
echo "gRPC port: ${QDRANT_GRPC_PORT}"
echo "Data: ${DATA_DIR}"
echo ""
echo "API Key: ${QDRANT_API_KEY}"
echo ""
echo "Dashboard:"
echo "  http://${SERVER_IP}:${QDRANT_HTTP_PORT}/dashboard"
echo ""
echo "Test connection:"
echo "  curl -H 'api-key: ${QDRANT_API_KEY}' http://${SERVER_IP}:${QDRANT_HTTP_PORT}/collections"
echo ""
echo "Uninstall:"
echo "  sudo ./qdrant.sh --uninstall"
echo ""
