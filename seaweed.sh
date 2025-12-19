#!/usr/bin/env bash
#
# seaweed.sh - Install SeaweedFS distributed storage in Docker
#
# Usage:
#   sudo ./seaweed.sh                     # Interactive mode
#   sudo ./seaweed.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   SEAWEED_S3_PORT        - S3 API port (default: 8333)
#   SEAWEED_MASTER_PORT    - Master port (default: 9333)
#   SEAWEED_VOLUME_PORT    - Volume port (default: 8080)
#   SEAWEED_FILER_PORT     - Filer port (default: 8888)
#   SEAWEED_S3_ACCESS_KEY  - S3 access key (default: admin)
#   SEAWEED_S3_SECRET_KEY  - S3 secret key (required)
#   DATA_DIR               - Data directory (default: /data/seaweedfs)
#   SEAWEED_VERSION        - Image version (default: 3.79)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="seaweedfs"
DEFAULT_DATA_DIR="/data/seaweedfs"
SEAWEED_S3_PORT="${SEAWEED_S3_PORT:-8333}"
SEAWEED_MASTER_PORT="${SEAWEED_MASTER_PORT:-9333}"
SEAWEED_VOLUME_PORT="${SEAWEED_VOLUME_PORT:-8080}"
SEAWEED_FILER_PORT="${SEAWEED_FILER_PORT:-8888}"
SEAWEED_VERSION="${SEAWEED_VERSION:-3.79}"

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
      echo "Secret key cannot be empty. Please try again."
      continue
    fi
    read -s -p "Confirm ${prompt_text}: " password_confirm
    echo ""
    if [[ "${password}" != "${password_confirm}" ]]; then
      echo "Secret keys do not match. Please try again."
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
  log "Uninstalling SeaweedFS..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  read -p "Remove config /etc/seaweedfs? [y/N]: " REMOVE_CONFIG
  if [[ "${REMOVE_CONFIG}" =~ ^[Yy]$ ]]; then
    rm -rf /etc/seaweedfs
    log "Config removed"
  fi
  log "SeaweedFS uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "SeaweedFS Setup"
echo "==============="
echo ""

if [[ -z "${SEAWEED_S3_PORT:-}" ]] || [[ "${SEAWEED_S3_PORT}" == "8333" ]]; then
  read -p "S3 API port [8333]: " SEAWEED_S3_PORT_INPUT
  SEAWEED_S3_PORT="${SEAWEED_S3_PORT_INPUT:-8333}"
fi

if [[ -z "${SEAWEED_MASTER_PORT:-}" ]] || [[ "${SEAWEED_MASTER_PORT}" == "9333" ]]; then
  read -p "Master port [9333]: " SEAWEED_MASTER_PORT_INPUT
  SEAWEED_MASTER_PORT="${SEAWEED_MASTER_PORT_INPUT:-9333}"
fi

if [[ -z "${SEAWEED_VOLUME_PORT:-}" ]] || [[ "${SEAWEED_VOLUME_PORT}" == "8080" ]]; then
  read -p "Volume port [8080]: " SEAWEED_VOLUME_PORT_INPUT
  SEAWEED_VOLUME_PORT="${SEAWEED_VOLUME_PORT_INPUT:-8080}"
fi

if [[ -z "${SEAWEED_FILER_PORT:-}" ]] || [[ "${SEAWEED_FILER_PORT}" == "8888" ]]; then
  read -p "Filer port [8888]: " SEAWEED_FILER_PORT_INPUT
  SEAWEED_FILER_PORT="${SEAWEED_FILER_PORT_INPUT:-8888}"
fi

if [[ -z "${SEAWEED_S3_ACCESS_KEY:-}" ]]; then
  read -p "S3 Access Key [admin]: " SEAWEED_S3_ACCESS_KEY
  SEAWEED_S3_ACCESS_KEY="${SEAWEED_S3_ACCESS_KEY:-admin}"
fi

if [[ -z "${SEAWEED_S3_SECRET_KEY:-}" ]]; then
  prompt_password SEAWEED_S3_SECRET_KEY "S3 Secret Key"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing SeaweedFS container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- Create S3 config ----------
mkdir -p /etc/seaweedfs
cat > /etc/seaweedfs/s3.json <<EOF
{
  "identities": [
    {
      "name": "admin",
      "credentials": [
        {
          "accessKey": "${SEAWEED_S3_ACCESS_KEY}",
          "secretKey": "${SEAWEED_S3_SECRET_KEY}"
        }
      ],
      "actions": ["Admin", "Read", "Write", "List", "Tagging"]
    }
  ]
}
EOF

# ---------- Run container ----------
log "Starting SeaweedFS ${SEAWEED_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${SEAWEED_MASTER_PORT}:9333" \
  -p "${SEAWEED_VOLUME_PORT}:8080" \
  -p "${SEAWEED_FILER_PORT}:8888" \
  -p "${SEAWEED_S3_PORT}:8333" \
  -v "${DATA_DIR}:/data" \
  -v /etc/seaweedfs:/etc/seaweedfs \
  --health-cmd="wget -q --spider http://localhost:9333/cluster/status || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  chrislusf/seaweedfs:${SEAWEED_VERSION} server \
  -dir=/data \
  -s3 \
  -s3.config=/etc/seaweedfs/s3.json \
  -s3.port=8333

# ---------- Wait for healthy ----------
log "Waiting for SeaweedFS to be ready..."
if ! wait_for_port "${SEAWEED_MASTER_PORT}" 30; then
  echo "ERROR: SeaweedFS failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  SeaweedFS Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${SEAWEED_VERSION}"
echo "Master port: ${SEAWEED_MASTER_PORT}"
echo "Volume port: ${SEAWEED_VOLUME_PORT}"
echo "Filer port: ${SEAWEED_FILER_PORT}"
echo "S3 port: ${SEAWEED_S3_PORT}"
echo "Data: ${DATA_DIR}"
echo ""
echo "S3 Credentials:"
echo "  Access Key: ${SEAWEED_S3_ACCESS_KEY}"
echo "  Secret Key: ${SEAWEED_S3_SECRET_KEY}"
echo ""
echo "S3 Endpoint:"
echo "  http://${SERVER_IP}:${SEAWEED_S3_PORT}"
echo ""
echo "Master UI:"
echo "  http://${SERVER_IP}:${SEAWEED_MASTER_PORT}"
echo ""
echo "Uninstall:"
echo "  sudo ./seaweed.sh --uninstall"
echo ""
