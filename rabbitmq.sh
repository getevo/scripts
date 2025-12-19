#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="rabbitmq"
DEFAULT_DATA_DIR="/data/rabbitmq"

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- prompt for settings ----------
echo ""
echo "RabbitMQ Setup"
echo "=============="
echo ""

if [[ -z "${RABBITMQ_USER:-}" ]]; then
  read -p "Username [admin]: " RABBITMQ_USER
  RABBITMQ_USER="${RABBITMQ_USER:-admin}"
fi

if [[ -z "${RABBITMQ_PASSWORD:-}" ]]; then
  while true; do
    read -s -p "Password: " RABBITMQ_PASSWORD
    echo ""
    if [[ -z "${RABBITMQ_PASSWORD}" ]]; then
      echo "Password cannot be empty. Please try again."
    else
      break
    fi
  done
fi

if [[ -z "${RABBITMQ_PORT:-}" ]]; then
  read -p "AMQP port [5672]: " RABBITMQ_PORT_INPUT
  RABBITMQ_PORT="${RABBITMQ_PORT_INPUT:-5672}"
else
  RABBITMQ_PORT="${RABBITMQ_PORT:-5672}"
fi

if [[ -z "${RABBITMQ_MGMT_PORT:-}" ]]; then
  read -p "Management port [15672]: " RABBITMQ_MGMT_PORT_INPUT
  RABBITMQ_MGMT_PORT="${RABBITMQ_MGMT_PORT_INPUT:-15672}"
else
  RABBITMQ_MGMT_PORT="${RABBITMQ_MGMT_PORT:-15672}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing RabbitMQ container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- run rabbitmq container ----------
log "Starting RabbitMQ container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${RABBITMQ_PORT}:5672" \
  -p "${RABBITMQ_MGMT_PORT}:15672" \
  -v "${DATA_DIR}:/var/lib/rabbitmq" \
  -e RABBITMQ_DEFAULT_USER="${RABBITMQ_USER}" \
  -e RABBITMQ_DEFAULT_PASS="${RABBITMQ_PASSWORD}" \
  rabbitmq:3-management

# ---------- wait for rabbitmq to start ----------
log "Waiting for RabbitMQ to start..."
sleep 15

# ---------- get server ip ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  RabbitMQ Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "AMQP port: ${RABBITMQ_PORT}"
  echo "Management port: ${RABBITMQ_MGMT_PORT}"
  echo "Data: ${DATA_DIR}"
  echo ""
  echo "Credentials:"
  echo "  Username: ${RABBITMQ_USER}"
  echo "  Password: ${RABBITMQ_PASSWORD}"
  echo ""
  echo "Management UI:"
  echo "  http://${SERVER_IP}:${RABBITMQ_MGMT_PORT}"
  echo ""
  echo "AMQP URL:"
  echo "  amqp://${RABBITMQ_USER}:${RABBITMQ_PASSWORD}@${SERVER_IP}:${RABBITMQ_PORT}"
  echo ""
  echo "SAVE THE CREDENTIALS!"
  echo ""
else
  echo "ERROR: RabbitMQ container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
