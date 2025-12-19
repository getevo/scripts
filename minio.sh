#!/usr/bin/env bash
#
# minio.sh - Install MinIO S3-compatible storage in Docker
#
# Usage:
#   sudo ./minio.sh                     # Interactive mode
#   sudo ./minio.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   MINIO_ROOT_USER      - Root user/access key (default: minioadmin)
#   MINIO_ROOT_PASSWORD  - Root password/secret key (min 8 chars)
#   MINIO_API_PORT       - S3 API port (default: 9000)
#   MINIO_CONSOLE_PORT   - Console port (default: 9001)
#   DATA_DIR             - Data directory (default: /data/minio)
#   MINIO_VERSION        - Image version (default: RELEASE.2024-11-07T00-52-20Z)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="minio"
DEFAULT_DATA_DIR="/data/minio"
MINIO_API_PORT="${MINIO_API_PORT:-9000}"
MINIO_CONSOLE_PORT="${MINIO_CONSOLE_PORT:-9001}"
MINIO_VERSION="${MINIO_VERSION:-RELEASE.2024-11-07T00-52-20Z}"

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
  local min_length="${3:-8}"
  while true; do
    read -s -p "${prompt_text}: " password
    echo ""
    if [[ -z "${password}" ]]; then
      echo "Password cannot be empty. Please try again."
      continue
    fi
    if [[ ${#password} -lt ${min_length} ]]; then
      echo "Password must be at least ${min_length} characters. Please try again."
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
  log "Uninstalling MinIO..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  log "MinIO uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "MinIO Setup"
echo "==========="
echo ""

if [[ -z "${MINIO_ROOT_USER:-}" ]]; then
  read -p "Root user (access key) [minioadmin]: " MINIO_ROOT_USER
  MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
fi

if [[ -z "${MINIO_ROOT_PASSWORD:-}" ]]; then
  prompt_password MINIO_ROOT_PASSWORD "Root password (secret key, min 8 chars)" 8
fi

if [[ -z "${MINIO_API_PORT:-}" ]] || [[ "${MINIO_API_PORT}" == "9000" ]]; then
  read -p "API port [9000]: " MINIO_API_PORT_INPUT
  MINIO_API_PORT="${MINIO_API_PORT_INPUT:-9000}"
fi

if [[ -z "${MINIO_CONSOLE_PORT:-}" ]] || [[ "${MINIO_CONSOLE_PORT}" == "9001" ]]; then
  read -p "Console port [9001]: " MINIO_CONSOLE_PORT_INPUT
  MINIO_CONSOLE_PORT="${MINIO_CONSOLE_PORT_INPUT:-9001}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing MinIO container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- Run container ----------
log "Starting MinIO ${MINIO_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${MINIO_API_PORT}:9000" \
  -p "${MINIO_CONSOLE_PORT}:9001" \
  -v "${DATA_DIR}:/data" \
  -e MINIO_ROOT_USER="${MINIO_ROOT_USER}" \
  -e MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD}" \
  --health-cmd="curl -f http://localhost:9000/minio/health/live || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  minio/minio:${MINIO_VERSION} server /data --console-address ":9001"

# ---------- Wait for healthy ----------
log "Waiting for MinIO to be ready..."
if ! wait_for_port "${MINIO_API_PORT}" 30; then
  echo "ERROR: MinIO failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  MinIO Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${MINIO_VERSION}"
echo "API port: ${MINIO_API_PORT}"
echo "Console port: ${MINIO_CONSOLE_PORT}"
echo "Data: ${DATA_DIR}"
echo ""
echo "Credentials:"
echo "  Access Key: ${MINIO_ROOT_USER}"
echo "  Secret Key: ${MINIO_ROOT_PASSWORD}"
echo ""
echo "Console UI:"
echo "  http://${SERVER_IP}:${MINIO_CONSOLE_PORT}"
echo ""
echo "S3 Endpoint:"
echo "  http://${SERVER_IP}:${MINIO_API_PORT}"
echo ""
echo "Uninstall:"
echo "  sudo ./minio.sh --uninstall"
echo ""
