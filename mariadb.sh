#!/usr/bin/env bash
#
# mariadb.sh - Install MariaDB in Docker
#
# Usage:
#   sudo ./mariadb.sh                     # Interactive mode
#   sudo ./mariadb.sh --uninstall         # Remove container and optionally data
#   sudo ./mariadb.sh user password       # With arguments
#
# Environment Variables:
#   MARIADB_USER      - Database username (default: root)
#   MARIADB_PASSWORD  - Database password (required)
#   MARIADB_PORT      - Port to expose (default: 3306)
#   DATA_DIR          - Data directory (default: /data/mariadb)
#   MARIADB_VERSION   - Image version (default: 11.4)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="mariadb"
DEFAULT_DATA_DIR="/data/mariadb"
MARIADB_PORT="${MARIADB_PORT:-3306}"
MARIADB_VERSION="${MARIADB_VERSION:-11.4}"

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
  log "Uninstalling MariaDB..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  log "MariaDB uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "MariaDB Setup"
echo "============="
echo ""

MARIADB_USER="${1:-${MARIADB_USER:-}}"
MARIADB_PASSWORD="${2:-${MARIADB_PASSWORD:-}}"

if [[ -z "${MARIADB_USER}" ]]; then
  read -p "Username [root]: " MARIADB_USER
  MARIADB_USER="${MARIADB_USER:-root}"
fi

if [[ -z "${MARIADB_PASSWORD}" ]]; then
  prompt_password MARIADB_PASSWORD "Password"
fi

if [[ -z "${MARIADB_PORT:-}" ]] || [[ "${MARIADB_PORT}" == "3306" ]]; then
  read -p "Port [3306]: " MARIADB_PORT_INPUT
  MARIADB_PORT="${MARIADB_PORT_INPUT:-3306}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing MariaDB container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- Run container ----------
log "Starting MariaDB ${MARIADB_VERSION}..."
if [[ "${MARIADB_USER}" == "root" ]]; then
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart=unless-stopped \
    -p "${MARIADB_PORT}:3306" \
    -v "${DATA_DIR}:/var/lib/mysql" \
    -e MARIADB_ROOT_PASSWORD="${MARIADB_PASSWORD}" \
    --health-cmd="healthcheck.sh --connect --innodb_initialized" \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=5 \
    mariadb:${MARIADB_VERSION}
else
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart=unless-stopped \
    -p "${MARIADB_PORT}:3306" \
    -v "${DATA_DIR}:/var/lib/mysql" \
    -e MARIADB_ROOT_PASSWORD="${MARIADB_PASSWORD}" \
    -e MARIADB_USER="${MARIADB_USER}" \
    -e MARIADB_PASSWORD="${MARIADB_PASSWORD}" \
    --health-cmd="healthcheck.sh --connect --innodb_initialized" \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=5 \
    mariadb:${MARIADB_VERSION}
fi

# ---------- Wait for healthy ----------
log "Waiting for MariaDB to be ready..."
if ! wait_for_port "${MARIADB_PORT}" 45; then
  echo "ERROR: MariaDB failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

log "Done."
echo ""
echo "=========================================="
echo "  MariaDB Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${MARIADB_VERSION}"
echo "Port: ${MARIADB_PORT}"
echo "Data: ${DATA_DIR}"
echo "User: ${MARIADB_USER}"
echo "Password: ${MARIADB_PASSWORD}"
echo ""
echo "Connect:"
echo "  docker exec -it ${CONTAINER_NAME} mariadb -u${MARIADB_USER} -p'${MARIADB_PASSWORD}'"
echo ""
echo "Uninstall:"
echo "  sudo ./mariadb.sh --uninstall"
echo ""
