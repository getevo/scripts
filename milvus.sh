#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="milvus"
DEFAULT_DATA_DIR="/data/milvus"

# ---------- prompt for configuration ----------
echo ""
echo "Milvus Setup"
echo "============"
echo ""

if [[ -z "${MILVUS_USERNAME:-}" ]]; then
  read -p "Username [root]: " MILVUS_USERNAME
  MILVUS_USERNAME="${MILVUS_USERNAME:-root}"
fi

if [[ -z "${MILVUS_PASSWORD:-}" ]]; then
  while true; do
    read -s -p "Password: " MILVUS_PASSWORD
    echo ""
    if [[ -z "${MILVUS_PASSWORD}" ]]; then
      echo "Password cannot be empty. Please try again."
    else
      read -s -p "Confirm password: " MILVUS_PASSWORD_CONFIRM
      echo ""
      if [[ "${MILVUS_PASSWORD}" != "${MILVUS_PASSWORD_CONFIRM}" ]]; then
        echo "Passwords do not match. Please try again."
      else
        break
      fi
    fi
  done
fi

if [[ -z "${MILVUS_PORT:-}" ]] || [[ "${MILVUS_PORT}" == "19530" ]]; then
  read -p "Port [19530]: " MILVUS_PORT_INPUT
  MILVUS_PORT="${MILVUS_PORT_INPUT:-19530}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- remove existing containers ----------
log "Removing existing Milvus containers..."
docker stop milvus-etcd milvus-minio "${CONTAINER_NAME}" 2>/dev/null || true
docker rm milvus-etcd milvus-minio "${CONTAINER_NAME}" 2>/dev/null || true

# ---------- create data directories ----------
log "Creating data directories: ${DATA_DIR}"
mkdir -p "${DATA_DIR}/etcd"
mkdir -p "${DATA_DIR}/minio"
mkdir -p "${DATA_DIR}/milvus"

# ---------- create docker network ----------
docker network create milvus-net 2>/dev/null || true

# ---------- run etcd ----------
log "Starting etcd..."
docker run -d \
  --name milvus-etcd \
  --network milvus-net \
  --restart=always \
  -v "${DATA_DIR}/etcd:/etcd" \
  -e ETCD_AUTO_COMPACTION_MODE=revision \
  -e ETCD_AUTO_COMPACTION_RETENTION=1000 \
  -e ETCD_QUOTA_BACKEND_BYTES=4294967296 \
  -e ETCD_SNAPSHOT_COUNT=50000 \
  quay.io/coreos/etcd:v3.5.5 \
  etcd \
  --advertise-client-urls=http://127.0.0.1:2379 \
  --listen-client-urls=http://0.0.0.0:2379 \
  --data-dir=/etcd

# ---------- run minio ----------
log "Starting MinIO..."
docker run -d \
  --name milvus-minio \
  --network milvus-net \
  --restart=always \
  -v "${DATA_DIR}/minio:/minio_data" \
  -e MINIO_ACCESS_KEY=minioadmin \
  -e MINIO_SECRET_KEY=minioadmin \
  minio/minio:RELEASE.2023-03-20T20-16-18Z \
  server /minio_data --console-address ":9001"

sleep 3

# ---------- run milvus ----------
log "Starting Milvus..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --network milvus-net \
  --restart=always \
  -p "${MILVUS_PORT}:19530" \
  -p 9091:9091 \
  -v "${DATA_DIR}/milvus:/var/lib/milvus" \
  -e ETCD_ENDPOINTS=milvus-etcd:2379 \
  -e MINIO_ADDRESS=milvus-minio:9000 \
  -e COMMON_SECURITY_AUTHORIZATIONENABLED=true \
  milvusdb/milvus:v2.4.0 \
  milvus run standalone

# ---------- wait for milvus to start ----------
log "Waiting for Milvus to start..."
sleep 15

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  Milvus Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "Port: ${MILVUS_PORT}"
  echo "Data directory: ${DATA_DIR}"
  echo "Username: ${MILVUS_USERNAME}"
  echo "Password: (hidden)"
  echo ""
  echo "Note: Default credentials are root/Milvus."
  echo "      Change password after first login."
  echo ""
  echo "Connect with pymilvus:"
  echo "  from pymilvus import connections"
  echo "  connections.connect(host='localhost', port='${MILVUS_PORT}', user='${MILVUS_USERNAME}', password='<password>')"
  echo ""
else
  echo "ERROR: Milvus container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
