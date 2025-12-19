#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="mongodb"
DATA_DIR="/data/mongodb"
MONGO_PORT="${MONGO_PORT:-27017}"

# ---------- prompt for credentials ----------
echo ""
echo "MongoDB Setup"
echo "============="
echo ""

if [[ -z "${MONGO_ROOT_USERNAME:-}" ]]; then
  read -p "Root username [root]: " MONGO_ROOT_USERNAME
  MONGO_ROOT_USERNAME="${MONGO_ROOT_USERNAME:-root}"
fi

if [[ -z "${MONGO_ROOT_PASSWORD:-}" ]]; then
  while true; do
    read -s -p "Root password: " MONGO_ROOT_PASSWORD
    echo ""
    if [[ -z "${MONGO_ROOT_PASSWORD}" ]]; then
      echo "Password cannot be empty. Please try again."
    else
      read -s -p "Confirm password: " MONGO_ROOT_PASSWORD_CONFIRM
      echo ""
      if [[ "${MONGO_ROOT_PASSWORD}" != "${MONGO_ROOT_PASSWORD_CONFIRM}" ]]; then
        echo "Passwords do not match. Please try again."
      else
        break
      fi
    fi
  done
fi

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing MongoDB container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- run mongodb container ----------
log "Starting MongoDB container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${MONGO_PORT}:27017" \
  -v "${DATA_DIR}:/data/db" \
  -e MONGO_INITDB_ROOT_USERNAME="${MONGO_ROOT_USERNAME}" \
  -e MONGO_INITDB_ROOT_PASSWORD="${MONGO_ROOT_PASSWORD}" \
  mongo:7

# ---------- wait for mongodb to start ----------
log "Waiting for MongoDB to start..."
sleep 10

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  MongoDB Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "Port: ${MONGO_PORT}"
  echo "Data directory: ${DATA_DIR}"
  echo "Username: ${MONGO_ROOT_USERNAME}"
  echo "Password: (hidden)"
  echo ""
  echo "Connect:"
  echo "  docker exec -it ${CONTAINER_NAME} mongosh -u ${MONGO_ROOT_USERNAME} -p"
  echo ""
  echo "Connection string:"
  echo "  mongodb://${MONGO_ROOT_USERNAME}:<password>@localhost:${MONGO_PORT}/"
  echo ""
else
  echo "ERROR: MongoDB container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
