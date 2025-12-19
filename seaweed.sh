#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="seaweedfs"
DEFAULT_DATA_DIR="/data/seaweedfs"

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- prompt for settings ----------
echo ""
echo "SeaweedFS Setup"
echo "==============="
echo ""

if [[ -z "${SEAWEED_S3_PORT:-}" ]]; then
  read -p "S3 API port [8333]: " SEAWEED_S3_PORT
  SEAWEED_S3_PORT="${SEAWEED_S3_PORT:-8333}"
fi

if [[ -z "${SEAWEED_MASTER_PORT:-}" ]]; then
  read -p "Master port [9333]: " SEAWEED_MASTER_PORT
  SEAWEED_MASTER_PORT="${SEAWEED_MASTER_PORT:-9333}"
fi

if [[ -z "${SEAWEED_VOLUME_PORT:-}" ]]; then
  read -p "Volume port [8080]: " SEAWEED_VOLUME_PORT
  SEAWEED_VOLUME_PORT="${SEAWEED_VOLUME_PORT:-8080}"
fi

if [[ -z "${SEAWEED_FILER_PORT:-}" ]]; then
  read -p "Filer port [8888]: " SEAWEED_FILER_PORT
  SEAWEED_FILER_PORT="${SEAWEED_FILER_PORT:-8888}"
fi

if [[ -z "${SEAWEED_S3_ACCESS_KEY:-}" ]]; then
  read -p "S3 Access Key [admin]: " SEAWEED_S3_ACCESS_KEY
  SEAWEED_S3_ACCESS_KEY="${SEAWEED_S3_ACCESS_KEY:-admin}"
fi

if [[ -z "${SEAWEED_S3_SECRET_KEY:-}" ]]; then
  read -s -p "S3 Secret Key [admin123]: " SEAWEED_S3_SECRET_KEY
  echo ""
  SEAWEED_S3_SECRET_KEY="${SEAWEED_S3_SECRET_KEY:-admin123}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing SeaweedFS container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create data directory ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"

# ---------- create s3 config ----------
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

# ---------- run seaweedfs container ----------
log "Starting SeaweedFS container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${SEAWEED_MASTER_PORT}:9333" \
  -p "${SEAWEED_VOLUME_PORT}:8080" \
  -p "${SEAWEED_FILER_PORT}:8888" \
  -p "${SEAWEED_S3_PORT}:8333" \
  -v "${DATA_DIR}:/data" \
  -v /etc/seaweedfs:/etc/seaweedfs \
  chrislusf/seaweedfs:latest server \
  -dir=/data \
  -s3 \
  -s3.config=/etc/seaweedfs/s3.json \
  -s3.port=8333

# ---------- wait for seaweedfs to start ----------
log "Waiting for SeaweedFS to start..."
sleep 10

# ---------- get server ip ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  SeaweedFS Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "Master port: ${SEAWEED_MASTER_PORT}"
  echo "Volume port: ${SEAWEED_VOLUME_PORT}"
  echo "Filer port: ${SEAWEED_FILER_PORT}"
  echo "S3 port: ${SEAWEED_S3_PORT}"
  echo "Data directory: ${DATA_DIR}"
  echo ""
  echo "S3 Credentials:"
  echo "  Access Key: ${SEAWEED_S3_ACCESS_KEY}"
  echo "  Secret Key: (hidden)"
  echo ""
  echo "S3 Endpoint:"
  echo "  http://${SERVER_IP}:${SEAWEED_S3_PORT}"
  echo ""
  echo "Master UI:"
  echo "  http://${SERVER_IP}:${SEAWEED_MASTER_PORT}"
  echo ""
else
  echo "ERROR: SeaweedFS container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
