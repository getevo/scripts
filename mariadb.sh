#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="mariadb"
DATA_DIR="/data/mariadb"
MARIADB_PORT="${MARIADB_PORT:-3306}"

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- get credentials ----------
MARIADB_USER="${1:-}"
MARIADB_PASSWORD="${2:-}"

if [[ -z "${MARIADB_USER}" ]]; then
  echo ""
  read -p "Enter MariaDB username [root]: " MARIADB_USER
  MARIADB_USER="${MARIADB_USER:-root}"
fi

if [[ -z "${MARIADB_PASSWORD}" ]]; then
  read -s -p "Enter MariaDB password: " MARIADB_PASSWORD
  echo ""
  if [[ -z "${MARIADB_PASSWORD}" ]]; then
    echo "ERROR: Password cannot be empty"
    exit 1
  fi
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing MariaDB container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- run mariadb container ----------
log "Starting MariaDB container..."
if [[ "${MARIADB_USER}" == "root" ]]; then
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart=always \
    -p "${MARIADB_PORT}:3306" \
    -v "${DATA_DIR}:/var/lib/mysql" \
    -e MARIADB_ROOT_PASSWORD="${MARIADB_PASSWORD}" \
    mariadb:11
else
  docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart=always \
    -p "${MARIADB_PORT}:3306" \
    -v "${DATA_DIR}:/var/lib/mysql" \
    -e MARIADB_ROOT_PASSWORD="${MARIADB_PASSWORD}" \
    -e MARIADB_USER="${MARIADB_USER}" \
    -e MARIADB_PASSWORD="${MARIADB_PASSWORD}" \
    mariadb:11
fi

# ---------- wait for mariadb to start ----------
log "Waiting for MariaDB to start..."
sleep 10

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  MariaDB Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "Port: ${MARIADB_PORT}"
  echo "Data directory: ${DATA_DIR}"
  echo "Username: ${MARIADB_USER}"
  echo ""
  echo "Connect:"
  echo "  docker exec -it ${CONTAINER_NAME} mariadb -u${MARIADB_USER} -p"
  echo ""
else
  echo "ERROR: MariaDB container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
