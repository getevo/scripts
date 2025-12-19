#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="clickhouse"
DATA_DIR="/data/clickhouse"
CLICKHOUSE_HTTP_PORT="${CLICKHOUSE_HTTP_PORT:-8123}"
CLICKHOUSE_NATIVE_PORT="${CLICKHOUSE_NATIVE_PORT:-9000}"

# ---------- prompt for credentials ----------
echo ""
echo "ClickHouse Setup"
echo "================"
echo ""

if [[ -z "${CLICKHOUSE_USER:-}" ]]; then
  read -p "Username [default]: " CLICKHOUSE_USER
  CLICKHOUSE_USER="${CLICKHOUSE_USER:-default}"
fi

if [[ -z "${CLICKHOUSE_PASSWORD:-}" ]]; then
  while true; do
    read -s -p "Password: " CLICKHOUSE_PASSWORD
    echo ""
    if [[ -z "${CLICKHOUSE_PASSWORD}" ]]; then
      echo "Password cannot be empty. Please try again."
    else
      read -s -p "Confirm password: " CLICKHOUSE_PASSWORD_CONFIRM
      echo ""
      if [[ "${CLICKHOUSE_PASSWORD}" != "${CLICKHOUSE_PASSWORD_CONFIRM}" ]]; then
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
  log "Removing existing ClickHouse container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- run clickhouse container ----------
log "Starting ClickHouse container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${CLICKHOUSE_HTTP_PORT}:8123" \
  -p "${CLICKHOUSE_NATIVE_PORT}:9000" \
  -v "${DATA_DIR}:/var/lib/clickhouse" \
  -e CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1 \
  -e CLICKHOUSE_USER="${CLICKHOUSE_USER}" \
  -e CLICKHOUSE_PASSWORD="${CLICKHOUSE_PASSWORD}" \
  clickhouse/clickhouse-server:latest

# ---------- wait for clickhouse to start ----------
log "Waiting for ClickHouse to start..."
sleep 10

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  ClickHouse Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "HTTP port: ${CLICKHOUSE_HTTP_PORT}"
  echo "Native port: ${CLICKHOUSE_NATIVE_PORT}"
  echo "Data directory: ${DATA_DIR}"
  echo "User: ${CLICKHOUSE_USER}"
  echo "Password: (hidden)"
  echo ""
  echo "Connect:"
  echo "  docker exec -it ${CONTAINER_NAME} clickhouse-client --user ${CLICKHOUSE_USER} --password"
  echo ""
  echo "HTTP API:"
  echo "  curl 'http://localhost:${CLICKHOUSE_HTTP_PORT}/?user=${CLICKHOUSE_USER}&password=<password>'"
  echo ""
  echo "SAVE THE PASSWORD!"
  echo ""
else
  echo "ERROR: ClickHouse container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
