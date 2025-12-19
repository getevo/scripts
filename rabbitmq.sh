#!/usr/bin/env bash
#
# rabbitmq.sh - Install RabbitMQ message broker in Docker
#
# Usage:
#   sudo ./rabbitmq.sh                     # Interactive mode
#   sudo ./rabbitmq.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   RABBITMQ_USER      - Username (default: admin)
#   RABBITMQ_PASSWORD  - Password (required)
#   RABBITMQ_PORT      - AMQP port (default: 5672)
#   RABBITMQ_MGMT_PORT - Management UI port (default: 15672)
#   DATA_DIR           - Data directory (default: /data/rabbitmq)
#   RABBITMQ_VERSION   - Image version (default: 3.13-management)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="rabbitmq"
DEFAULT_DATA_DIR="/data/rabbitmq"
RABBITMQ_PORT="${RABBITMQ_PORT:-5672}"
RABBITMQ_MGMT_PORT="${RABBITMQ_MGMT_PORT:-15672}"
RABBITMQ_VERSION="${RABBITMQ_VERSION:-3.13-management}"

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
  log "Uninstalling RabbitMQ..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  log "RabbitMQ uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "RabbitMQ Setup"
echo "=============="
echo ""

if [[ -z "${RABBITMQ_USER:-}" ]]; then
  read -p "Username [admin]: " RABBITMQ_USER
  RABBITMQ_USER="${RABBITMQ_USER:-admin}"
fi

if [[ -z "${RABBITMQ_PASSWORD:-}" ]]; then
  prompt_password RABBITMQ_PASSWORD "Password"
fi

if [[ -z "${RABBITMQ_PORT:-}" ]] || [[ "${RABBITMQ_PORT}" == "5672" ]]; then
  read -p "AMQP port [5672]: " RABBITMQ_PORT_INPUT
  RABBITMQ_PORT="${RABBITMQ_PORT_INPUT:-5672}"
fi

if [[ -z "${RABBITMQ_MGMT_PORT:-}" ]] || [[ "${RABBITMQ_MGMT_PORT}" == "15672" ]]; then
  read -p "Management port [15672]: " RABBITMQ_MGMT_PORT_INPUT
  RABBITMQ_MGMT_PORT="${RABBITMQ_MGMT_PORT_INPUT:-15672}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing RabbitMQ container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- Run container ----------
log "Starting RabbitMQ ${RABBITMQ_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${RABBITMQ_PORT}:5672" \
  -p "${RABBITMQ_MGMT_PORT}:15672" \
  -v "${DATA_DIR}:/var/lib/rabbitmq" \
  -e RABBITMQ_DEFAULT_USER="${RABBITMQ_USER}" \
  -e RABBITMQ_DEFAULT_PASS="${RABBITMQ_PASSWORD}" \
  --health-cmd="rabbitmq-diagnostics -q ping" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  rabbitmq:${RABBITMQ_VERSION}

# ---------- Wait for healthy ----------
log "Waiting for RabbitMQ to be ready..."
if ! wait_for_port "${RABBITMQ_PORT}" 60; then
  echo "ERROR: RabbitMQ failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  RabbitMQ Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${RABBITMQ_VERSION}"
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
echo "Uninstall:"
echo "  sudo ./rabbitmq.sh --uninstall"
echo ""
