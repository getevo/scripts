#!/usr/bin/env bash
#
# mongodb.sh - Install MongoDB in Docker
#
# Usage:
#   sudo ./mongodb.sh                     # Interactive mode
#   sudo ./mongodb.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   MONGO_ROOT_USERNAME  - Root username (default: root)
#   MONGO_ROOT_PASSWORD  - Root password (required)
#   MONGO_PORT           - Port to expose (default: 27017)
#   DATA_DIR             - Data directory (default: /data/mongodb)
#   MONGO_VERSION        - Image version (default: 7.0)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="mongodb"
DEFAULT_DATA_DIR="/data/mongodb"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_VERSION="${MONGO_VERSION:-7.0}"

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
      echo "Password cannot be empty. Please try again."
      continue
    fi
    read -s -p "Confirm ${prompt_text}: " password_confirm
    echo ""
    if [[ "${password}" != "${password_confirm}" ]]; then
      echo "Passwords do not match. Please try again."
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
  log "Uninstalling MongoDB..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  log "MongoDB uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "MongoDB Setup"
echo "============="
echo ""

if [[ -z "${MONGO_ROOT_USERNAME:-}" ]]; then
  read -p "Root username [root]: " MONGO_ROOT_USERNAME
  MONGO_ROOT_USERNAME="${MONGO_ROOT_USERNAME:-root}"
fi

if [[ -z "${MONGO_ROOT_PASSWORD:-}" ]]; then
  prompt_password MONGO_ROOT_PASSWORD "Root password"
fi

if [[ -z "${MONGO_PORT:-}" ]] || [[ "${MONGO_PORT}" == "27017" ]]; then
  read -p "Port [27017]: " MONGO_PORT_INPUT
  MONGO_PORT="${MONGO_PORT_INPUT:-27017}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing MongoDB container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- Run container ----------
log "Starting MongoDB ${MONGO_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${MONGO_PORT}:27017" \
  -v "${DATA_DIR}:/data/db" \
  -e MONGO_INITDB_ROOT_USERNAME="${MONGO_ROOT_USERNAME}" \
  -e MONGO_INITDB_ROOT_PASSWORD="${MONGO_ROOT_PASSWORD}" \
  --health-cmd="mongosh --eval 'db.adminCommand(\"ping\")' --quiet" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  mongo:${MONGO_VERSION}

# ---------- Wait for healthy ----------
log "Waiting for MongoDB to be ready..."
if ! wait_for_port "${MONGO_PORT}" 30; then
  echo "ERROR: MongoDB failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  MongoDB Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${MONGO_VERSION}"
echo "Port: ${MONGO_PORT}"
echo "Data: ${DATA_DIR}"
echo ""
echo "Credentials:"
echo "  Username: ${MONGO_ROOT_USERNAME}"
echo "  Password: ${MONGO_ROOT_PASSWORD}"
echo ""
echo "Connect:"
echo "  docker exec -it ${CONTAINER_NAME} mongosh -u ${MONGO_ROOT_USERNAME} -p '${MONGO_ROOT_PASSWORD}'"
echo ""
echo "Connection string:"
echo "  mongodb://${MONGO_ROOT_USERNAME}:${MONGO_ROOT_PASSWORD}@${SERVER_IP}:${MONGO_PORT}/"
echo ""
echo "Uninstall:"
echo "  sudo ./mongodb.sh --uninstall"
echo ""
