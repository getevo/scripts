#!/usr/bin/env bash
#
# redis.sh - Install Redis in Docker
#
# Usage:
#   sudo ./redis.sh                     # Interactive mode
#   sudo ./redis.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   REDIS_PASSWORD  - Database password (required)
#   REDIS_PORT      - Port to expose (default: 6379)
#   DATA_DIR        - Data directory (default: /data/redis)
#   REDIS_VERSION   - Image version (default: 7.4)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="redis"
DEFAULT_DATA_DIR="/data/redis"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_VERSION="${REDIS_VERSION:-7.4}"

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
  log "Uninstalling Redis..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  log "Redis uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "Redis Setup"
echo "==========="
echo ""

if [[ -z "${REDIS_PASSWORD:-}" ]]; then
  prompt_password REDIS_PASSWORD "Password"
fi

if [[ -z "${REDIS_PORT:-}" ]] || [[ "${REDIS_PORT}" == "6379" ]]; then
  read -p "Port [6379]: " REDIS_PORT_INPUT
  REDIS_PORT="${REDIS_PORT_INPUT:-6379}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing Redis container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- Run container ----------
log "Starting Redis ${REDIS_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${REDIS_PORT}:6379" \
  -v "${DATA_DIR}:/data" \
  --health-cmd="redis-cli -a '${REDIS_PASSWORD}' ping | grep PONG" \
  --health-interval=10s \
  --health-timeout=5s \
  --health-retries=5 \
  redis:${REDIS_VERSION} \
  redis-server --appendonly yes --requirepass "${REDIS_PASSWORD}"

# ---------- Wait for healthy ----------
log "Waiting for Redis to be ready..."
if ! wait_for_port "${REDIS_PORT}" 30; then
  echo "ERROR: Redis failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

log "Done."
echo ""
echo "=========================================="
echo "  Redis Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${REDIS_VERSION}"
echo "Port: ${REDIS_PORT}"
echo "Data: ${DATA_DIR}"
echo "Password: ${REDIS_PASSWORD}"
echo ""
echo "Connect:"
echo "  docker exec -it ${CONTAINER_NAME} redis-cli -a '${REDIS_PASSWORD}'"
echo "  redis-cli -h localhost -p ${REDIS_PORT} -a '${REDIS_PASSWORD}'"
echo ""
echo "Uninstall:"
echo "  sudo ./redis.sh --uninstall"
echo ""
