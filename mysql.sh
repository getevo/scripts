#!/usr/bin/env bash
#
# mysql.sh - Install MySQL in Docker
#
# Usage:
#   sudo ./mysql.sh                     # Interactive mode
#   sudo ./mysql.sh --uninstall         # Remove container and optionally data
#   sudo ./mysql.sh user password       # With arguments
#
# Environment Variables:
#   MYSQL_USER      - Database username (default: root)
#   MYSQL_PASSWORD  - Database password (required)
#   MYSQL_PORT      - Port to expose (default: 3306)
#   DATA_DIR        - Data directory (default: /data/mysql)
#   MYSQL_VERSION   - Image version (default: 8.0.40)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="mysql"
DEFAULT_DATA_DIR="/data/mysql"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_VERSION="${MYSQL_VERSION:-8.0.40}"

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
  log "Uninstalling MySQL..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  log "MySQL uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "MySQL Setup"
echo "==========="
echo ""

MYSQL_USER="${1:-${MYSQL_USER:-}}"
MYSQL_PASSWORD="${2:-${MYSQL_PASSWORD:-}}"

if [[ -z "${MYSQL_USER}" ]]; then
  read -p "Username [root]: " MYSQL_USER
  MYSQL_USER="${MYSQL_USER:-root}"
fi

if [[ -z "${MYSQL_PASSWORD}" ]]; then
  prompt_password MYSQL_PASSWORD "Password"
fi

if [[ -z "${MYSQL_PORT:-}" ]] || [[ "${MYSQL_PORT}" == "3306" ]]; then
  read -p "Port [3306]: " MYSQL_PORT_INPUT
  MYSQL_PORT="${MYSQL_PORT_INPUT:-3306}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing MySQL container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- Run container ----------
log "Starting MySQL ${MYSQL_VERSION}..."
if [[ "${MYSQL_USER}" == "root" ]]; then
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart=unless-stopped \
    -p "${MYSQL_PORT}:3306" \
    -v "${DATA_DIR}:/var/lib/mysql" \
    -e MYSQL_ROOT_PASSWORD="${MYSQL_PASSWORD}" \
    --health-cmd="mysqladmin ping -h localhost" \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=5 \
    mysql:${MYSQL_VERSION}
else
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart=unless-stopped \
    -p "${MYSQL_PORT}:3306" \
    -v "${DATA_DIR}:/var/lib/mysql" \
    -e MYSQL_ROOT_PASSWORD="${MYSQL_PASSWORD}" \
    -e MYSQL_USER="${MYSQL_USER}" \
    -e MYSQL_PASSWORD="${MYSQL_PASSWORD}" \
    --health-cmd="mysqladmin ping -h localhost" \
    --health-interval=10s \
    --health-timeout=5s \
    --health-retries=5 \
    mysql:${MYSQL_VERSION}
fi

# ---------- Wait for healthy ----------
log "Waiting for MySQL to be ready..."
if ! wait_for_port "${MYSQL_PORT}" 45; then
  echo "ERROR: MySQL failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

log "Done."
echo ""
echo "=========================================="
echo "  MySQL Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${MYSQL_VERSION}"
echo "Port: ${MYSQL_PORT}"
echo "Data: ${DATA_DIR}"
echo "User: ${MYSQL_USER}"
echo "Password: ${MYSQL_PASSWORD}"
echo ""
echo "Connect:"
echo "  docker exec -it ${CONTAINER_NAME} mysql -u${MYSQL_USER} -p'${MYSQL_PASSWORD}'"
echo ""
echo "Uninstall:"
echo "  sudo ./mysql.sh --uninstall"
echo ""
