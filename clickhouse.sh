#!/usr/bin/env bash
#
# clickhouse.sh - Install ClickHouse in Docker
#
# Usage:
#   sudo ./clickhouse.sh                     # Interactive mode
#   sudo ./clickhouse.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   CLICKHOUSE_USER        - Username (default: default)
#   CLICKHOUSE_PASSWORD    - Password (required)
#   CLICKHOUSE_HTTP_PORT   - HTTP port (default: 8123)
#   CLICKHOUSE_NATIVE_PORT - Native port (default: 9000)
#   DATA_DIR               - Data directory (default: /data/clickhouse)
#   CLICKHOUSE_VERSION     - Image version (default: 24.8)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="clickhouse"
DEFAULT_DATA_DIR="/data/clickhouse"
CLICKHOUSE_HTTP_PORT="${CLICKHOUSE_HTTP_PORT:-8123}"
CLICKHOUSE_NATIVE_PORT="${CLICKHOUSE_NATIVE_PORT:-9000}"
CLICKHOUSE_VERSION="${CLICKHOUSE_VERSION:-24.8}"

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
  log "Uninstalling ClickHouse..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  log "ClickHouse uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "ClickHouse Setup"
echo "================"
echo ""

if [[ -z "${CLICKHOUSE_USER:-}" ]]; then
  read -p "Username [default]: " CLICKHOUSE_USER
  CLICKHOUSE_USER="${CLICKHOUSE_USER:-default}"
fi

if [[ -z "${CLICKHOUSE_PASSWORD:-}" ]]; then
  prompt_password CLICKHOUSE_PASSWORD "Password"
fi

if [[ -z "${CLICKHOUSE_HTTP_PORT:-}" ]] || [[ "${CLICKHOUSE_HTTP_PORT}" == "8123" ]]; then
  read -p "HTTP port [8123]: " CLICKHOUSE_HTTP_PORT_INPUT
  CLICKHOUSE_HTTP_PORT="${CLICKHOUSE_HTTP_PORT_INPUT:-8123}"
fi

if [[ -z "${CLICKHOUSE_NATIVE_PORT:-}" ]] || [[ "${CLICKHOUSE_NATIVE_PORT}" == "9000" ]]; then
  read -p "Native port [9000]: " CLICKHOUSE_NATIVE_PORT_INPUT
  CLICKHOUSE_NATIVE_PORT="${CLICKHOUSE_NATIVE_PORT_INPUT:-9000}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing ClickHouse container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- Run container ----------
log "Starting ClickHouse ${CLICKHOUSE_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${CLICKHOUSE_HTTP_PORT}:8123" \
  -p "${CLICKHOUSE_NATIVE_PORT}:9000" \
  -v "${DATA_DIR}:/var/lib/clickhouse" \
  -e CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1 \
  -e CLICKHOUSE_USER="${CLICKHOUSE_USER}" \
  -e CLICKHOUSE_PASSWORD="${CLICKHOUSE_PASSWORD}" \
  --health-cmd="wget -q --spider http://localhost:8123/ping || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  --ulimit nofile=262144:262144 \
  clickhouse/clickhouse-server:${CLICKHOUSE_VERSION}

# ---------- Wait for healthy ----------
log "Waiting for ClickHouse to be ready..."
if ! wait_for_port "${CLICKHOUSE_HTTP_PORT}" 30; then
  echo "ERROR: ClickHouse failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  ClickHouse Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${CLICKHOUSE_VERSION}"
echo "HTTP port: ${CLICKHOUSE_HTTP_PORT}"
echo "Native port: ${CLICKHOUSE_NATIVE_PORT}"
echo "Data: ${DATA_DIR}"
echo ""
echo "Credentials:"
echo "  Username: ${CLICKHOUSE_USER}"
echo "  Password: ${CLICKHOUSE_PASSWORD}"
echo ""
echo "Connect:"
echo "  docker exec -it ${CONTAINER_NAME} clickhouse-client --user ${CLICKHOUSE_USER} --password '${CLICKHOUSE_PASSWORD}'"
echo ""
echo "HTTP API:"
echo "  curl 'http://${SERVER_IP}:${CLICKHOUSE_HTTP_PORT}/?user=${CLICKHOUSE_USER}&password=${CLICKHOUSE_PASSWORD}'"
echo ""
echo "Uninstall:"
echo "  sudo ./clickhouse.sh --uninstall"
echo ""
