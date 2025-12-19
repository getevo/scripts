#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="postgres"
DATA_DIR="/data/postgres"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- get credentials ----------
POSTGRES_USER="${1:-}"
POSTGRES_PASSWORD="${2:-}"

if [[ -z "${POSTGRES_USER}" ]]; then
  echo ""
  read -p "Enter PostgreSQL username [postgres]: " POSTGRES_USER
  POSTGRES_USER="${POSTGRES_USER:-postgres}"
fi

if [[ -z "${POSTGRES_PASSWORD}" ]]; then
  read -s -p "Enter PostgreSQL password: " POSTGRES_PASSWORD
  echo ""
  if [[ -z "${POSTGRES_PASSWORD}" ]]; then
    echo "ERROR: Password cannot be empty"
    exit 1
  fi
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing PostgreSQL container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- run postgres container ----------
log "Starting PostgreSQL container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${POSTGRES_PORT}:5432" \
  -v "${DATA_DIR}:/var/lib/postgresql/data" \
  -e POSTGRES_USER="${POSTGRES_USER}" \
  -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  postgres:16

# ---------- wait for postgres to start ----------
log "Waiting for PostgreSQL to start..."
sleep 10

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  PostgreSQL Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "Port: ${POSTGRES_PORT}"
  echo "Data directory: ${DATA_DIR}"
  echo "Username: ${POSTGRES_USER}"
  echo ""
  echo "Connect:"
  echo "  docker exec -it ${CONTAINER_NAME} psql -U ${POSTGRES_USER}"
  echo ""
else
  echo "ERROR: PostgreSQL container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
