#!/usr/bin/env bash
#
# milvus.sh - Install Milvus vector database in Docker
#
# Usage:
#   sudo ./milvus.sh                     # Interactive mode
#   sudo ./milvus.sh --uninstall         # Remove containers and optionally data
#
# Environment Variables:
#   MILVUS_USERNAME  - Username (default: root)
#   MILVUS_PASSWORD  - Password (note: default Milvus password is 'Milvus')
#   MILVUS_PORT      - Port (default: 19530)
#   DATA_DIR         - Data directory (default: /data/milvus)
#   MILVUS_VERSION   - Image version (default: v2.4.13)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="milvus"
DEFAULT_DATA_DIR="/data/milvus"
MILVUS_PORT="${MILVUS_PORT:-19530}"
MILVUS_VERSION="${MILVUS_VERSION:-v2.4.13}"
ETCD_VERSION="${ETCD_VERSION:-v3.5.5}"
MINIO_VERSION="${MINIO_VERSION:-RELEASE.2023-03-20T20-16-18Z}"

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
  log "Uninstalling Milvus..."
  docker stop milvus-etcd milvus-minio "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm milvus-etcd milvus-minio "${CONTAINER_NAME}" 2>/dev/null || true
  docker network rm milvus-net 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  log "Milvus uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "Milvus Setup"
echo "============"
echo ""

if [[ -z "${MILVUS_USERNAME:-}" ]]; then
  read -p "Username [root]: " MILVUS_USERNAME
  MILVUS_USERNAME="${MILVUS_USERNAME:-root}"
fi

if [[ -z "${MILVUS_PASSWORD:-}" ]]; then
  prompt_password MILVUS_PASSWORD "Password"
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

# ---------- Remove existing containers ----------
log "Removing existing Milvus containers..."
docker stop milvus-etcd milvus-minio "${CONTAINER_NAME}" 2>/dev/null || true
docker rm milvus-etcd milvus-minio "${CONTAINER_NAME}" 2>/dev/null || true

# ---------- Create data directories ----------
log "Creating data directories: ${DATA_DIR}"
mkdir -p "${DATA_DIR}/etcd"
mkdir -p "${DATA_DIR}/minio"
mkdir -p "${DATA_DIR}/milvus"

# ---------- Create docker network ----------
docker network create milvus-net 2>/dev/null || true

# ---------- Run etcd ----------
log "Starting etcd ${ETCD_VERSION}..."
docker run -d \
  --name milvus-etcd \
  --network milvus-net \
  --restart=unless-stopped \
  -v "${DATA_DIR}/etcd:/etcd" \
  -e ETCD_AUTO_COMPACTION_MODE=revision \
  -e ETCD_AUTO_COMPACTION_RETENTION=1000 \
  -e ETCD_QUOTA_BACKEND_BYTES=4294967296 \
  -e ETCD_SNAPSHOT_COUNT=50000 \
  --health-cmd="etcdctl endpoint health" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  quay.io/coreos/etcd:${ETCD_VERSION} \
  etcd \
  --advertise-client-urls=http://127.0.0.1:2379 \
  --listen-client-urls=http://0.0.0.0:2379 \
  --data-dir=/etcd

# ---------- Run minio ----------
log "Starting MinIO ${MINIO_VERSION}..."
docker run -d \
  --name milvus-minio \
  --network milvus-net \
  --restart=unless-stopped \
  -v "${DATA_DIR}/minio:/minio_data" \
  -e MINIO_ACCESS_KEY=minioadmin \
  -e MINIO_SECRET_KEY=minioadmin \
  --health-cmd="curl -f http://localhost:9000/minio/health/live || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  minio/minio:${MINIO_VERSION} \
  server /minio_data --console-address ":9001"

sleep 5

# ---------- Run milvus ----------
log "Starting Milvus ${MILVUS_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --network milvus-net \
  --restart=unless-stopped \
  -p "${MILVUS_PORT}:19530" \
  -p 9091:9091 \
  -v "${DATA_DIR}/milvus:/var/lib/milvus" \
  -e ETCD_ENDPOINTS=milvus-etcd:2379 \
  -e MINIO_ADDRESS=milvus-minio:9000 \
  -e COMMON_SECURITY_AUTHORIZATIONENABLED=true \
  --health-cmd="curl -f http://localhost:9091/healthz || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  milvusdb/milvus:${MILVUS_VERSION} \
  milvus run standalone

# ---------- Wait for healthy ----------
log "Waiting for Milvus to be ready..."
if ! wait_for_port "${MILVUS_PORT}" 60; then
  echo "ERROR: Milvus failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  Milvus Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${MILVUS_VERSION}"
echo "Port: ${MILVUS_PORT}"
echo "Data: ${DATA_DIR}"
echo ""
echo "Credentials:"
echo "  Username: ${MILVUS_USERNAME}"
echo "  Password: ${MILVUS_PASSWORD}"
echo ""
echo "Note: Default Milvus credentials are root/Milvus."
echo "      Change password after first login if needed."
echo ""
echo "Connect with pymilvus:"
echo "  from pymilvus import connections"
echo "  connections.connect(host='${SERVER_IP}', port='${MILVUS_PORT}', user='${MILVUS_USERNAME}', password='${MILVUS_PASSWORD}')"
echo ""
echo "Uninstall:"
echo "  sudo ./milvus.sh --uninstall"
echo ""
