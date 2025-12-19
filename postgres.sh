#!/usr/bin/env bash
#
# postgres.sh - Install PostgreSQL in Docker
#
# Usage:
#   sudo ./postgres.sh                     # Interactive mode
#   sudo ./postgres.sh --uninstall         # Remove container and optionally data
#   sudo ./postgres.sh user password       # With arguments
#
# Environment Variables:
#   POSTGRES_USER      - Database username (default: postgres)
#   POSTGRES_PASSWORD  - Database password (required)
#   POSTGRES_PORT      - Port to expose (default: 5432)
#   DATA_DIR           - Data directory (default: /data/postgres)
#   POSTGRES_VERSION   - Image version (default: 16.4)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="postgres"
DEFAULT_DATA_DIR="/data/postgres"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_VERSION="${POSTGRES_VERSION:-16.4}"

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
  log "Uninstalling PostgreSQL..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  log "PostgreSQL uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "PostgreSQL Setup"
echo "================"
echo ""

POSTGRES_USER="${1:-${POSTGRES_USER:-}}"
POSTGRES_PASSWORD="${2:-${POSTGRES_PASSWORD:-}}"

if [[ -z "${POSTGRES_USER}" ]]; then
  read -p "Username [postgres]: " POSTGRES_USER
  POSTGRES_USER="${POSTGRES_USER:-postgres}"
fi

if [[ -z "${POSTGRES_PASSWORD}" ]]; then
  prompt_password POSTGRES_PASSWORD "Password"
fi

if [[ -z "${POSTGRES_PORT:-}" ]] || [[ "${POSTGRES_PORT}" == "5432" ]]; then
  read -p "Port [5432]: " POSTGRES_PORT_INPUT
  POSTGRES_PORT="${POSTGRES_PORT_INPUT:-5432}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing PostgreSQL container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- Run container ----------
log "Starting PostgreSQL ${POSTGRES_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${POSTGRES_PORT}:5432" \
  -v "${DATA_DIR}:/var/lib/postgresql/data" \
  -e POSTGRES_USER="${POSTGRES_USER}" \
  -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  --health-cmd="pg_isready -U ${POSTGRES_USER}" \
  --health-interval=10s \
  --health-timeout=5s \
  --health-retries=5 \
  postgres:${POSTGRES_VERSION}

# ---------- Wait for healthy ----------
log "Waiting for PostgreSQL to be ready..."
if ! wait_for_port "${POSTGRES_PORT}" 30; then
  echo "ERROR: PostgreSQL failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

log "Done."
echo ""
echo "=========================================="
echo "  PostgreSQL Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${POSTGRES_VERSION}"
echo "Port: ${POSTGRES_PORT}"
echo "Data: ${DATA_DIR}"
echo "User: ${POSTGRES_USER}"
echo "Password: ${POSTGRES_PASSWORD}"
echo ""
echo "Connect:"
echo "  docker exec -it ${CONTAINER_NAME} psql -U ${POSTGRES_USER}"
echo "  PGPASSWORD='${POSTGRES_PASSWORD}' psql -h localhost -p ${POSTGRES_PORT} -U ${POSTGRES_USER}"
echo ""
echo "Uninstall:"
echo "  sudo ./postgres.sh --uninstall"
echo ""
