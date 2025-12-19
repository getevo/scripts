#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="mysql"
DATA_DIR="/data/mysql"
MYSQL_PORT="${MYSQL_PORT:-3306}"

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- get credentials ----------
MYSQL_USER="${1:-}"
MYSQL_PASSWORD="${2:-}"

if [[ -z "${MYSQL_USER}" ]]; then
  echo ""
  read -p "Enter MySQL username [root]: " MYSQL_USER
  MYSQL_USER="${MYSQL_USER:-root}"
fi

if [[ -z "${MYSQL_PASSWORD}" ]]; then
  read -s -p "Enter MySQL password: " MYSQL_PASSWORD
  echo ""
  if [[ -z "${MYSQL_PASSWORD}" ]]; then
    echo "ERROR: Password cannot be empty"
    exit 1
  fi
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing MySQL container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- run mysql container ----------
log "Starting MySQL container..."
if [[ "${MYSQL_USER}" == "root" ]]; then
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart=always \
    -p "${MYSQL_PORT}:3306" \
    -v "${DATA_DIR}:/var/lib/mysql" \
    -e MYSQL_ROOT_PASSWORD="${MYSQL_PASSWORD}" \
    mysql:8.0
else
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart=always \
    -p "${MYSQL_PORT}:3306" \
    -v "${DATA_DIR}:/var/lib/mysql" \
    -e MYSQL_ROOT_PASSWORD="${MYSQL_PASSWORD}" \
    -e MYSQL_USER="${MYSQL_USER}" \
    -e MYSQL_PASSWORD="${MYSQL_PASSWORD}" \
    mysql:8.0
fi

# ---------- wait for mysql to start ----------
log "Waiting for MySQL to start..."
sleep 10

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  MySQL Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "Port: ${MYSQL_PORT}"
  echo "Data directory: ${DATA_DIR}"
  echo "Username: ${MYSQL_USER}"
  echo ""
  echo "Connect:"
  echo "  docker exec -it ${CONTAINER_NAME} mysql -u${MYSQL_USER} -p"
  echo ""
else
  echo "ERROR: MySQL container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
