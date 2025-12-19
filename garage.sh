#!/usr/bin/env bash
#
# garage.sh - Install Garage S3-compatible storage in Docker
#
# Usage:
#   sudo ./garage.sh                     # Interactive mode
#   sudo ./garage.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   GARAGE_S3_PORT   - S3 API port (default: 3900)
#   GARAGE_RPC_PORT  - RPC port (default: 3901)
#   GARAGE_WEB_PORT  - Web port (default: 3902)
#   DATA_DIR         - Data directory (default: /data/garage)
#   GARAGE_VERSION   - Image version (default: v2.1.0)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="garage"
DEFAULT_DATA_DIR="/data/garage"
GARAGE_VERSION="${GARAGE_VERSION:-v2.1.0}"

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

wait_for_garage() {
  local max_attempts="${1:-30}"
  local attempt=1
  echo -n "Waiting for Garage CLI to be ready"
  while [[ $attempt -le $max_attempts ]]; do
    if docker exec "${CONTAINER_NAME}" /garage node id &>/dev/null; then
      echo " OK"
      return 0
    fi
    echo -n "."
    sleep 2
    ((attempt++))
  done
  echo " TIMEOUT"
  return 1
}

# Detect architecture for correct image
get_garage_image() {
  local arch
  arch=$(uname -m)
  case "${arch}" in
    x86_64|amd64)
      echo "dxflrs/garage:${GARAGE_VERSION}"
      ;;
    aarch64|arm64)
      echo "dxflrs/garage:${GARAGE_VERSION}"
      ;;
    *)
      echo "dxflrs/garage:${GARAGE_VERSION}"
      ;;
  esac
}

# ---------- Root check ----------
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- Uninstall mode ----------
if [[ "${1:-}" == "--uninstall" ]]; then
  log "Uninstalling Garage..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  read -p "Remove config /etc/garage? [y/N]: " REMOVE_CONFIG
  if [[ "${REMOVE_CONFIG}" =~ ^[Yy]$ ]]; then
    rm -rf /etc/garage
    log "Config removed"
  fi
  log "Garage uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "Garage S3 Setup"
echo "==============="
echo ""

if [[ -z "${GARAGE_S3_PORT:-}" ]]; then
  read -p "S3 API port [3900]: " GARAGE_S3_PORT
  GARAGE_S3_PORT="${GARAGE_S3_PORT:-3900}"
fi

if [[ -z "${GARAGE_RPC_PORT:-}" ]]; then
  read -p "RPC port [3901]: " GARAGE_RPC_PORT
  GARAGE_RPC_PORT="${GARAGE_RPC_PORT:-3901}"
fi

if [[ -z "${GARAGE_WEB_PORT:-}" ]]; then
  read -p "Web/Admin port [3902]: " GARAGE_WEB_PORT
  GARAGE_WEB_PORT="${GARAGE_WEB_PORT:-3902}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# Generate random secret for RPC
RPC_SECRET=$(openssl rand -hex 32)

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing Garage container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create directories ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}/meta"
mkdir -p "${DATA_DIR}/blocks"
mkdir -p /etc/garage

# ---------- Create Garage config ----------
log "Creating Garage configuration..."
cat > /etc/garage/garage.toml <<EOF
metadata_dir = "/data/meta"
data_dir = "/data/blocks"
db_engine = "sqlite"

replication_factor = 1

rpc_bind_addr = "[::]:3901"
rpc_secret = "${RPC_SECRET}"

[s3_api]
s3_region = "garage"
api_bind_addr = "[::]:3900"
root_domain = ".s3.garage.localhost"

[s3_web]
bind_addr = "[::]:3902"
root_domain = ".web.garage.localhost"

[admin]
api_bind_addr = "[::]:3903"
EOF

# ---------- Get correct image ----------
GARAGE_IMAGE=$(get_garage_image)
log "Using image: ${GARAGE_IMAGE}"

# ---------- Run container ----------
log "Starting Garage ${GARAGE_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${GARAGE_S3_PORT}:3900" \
  -p "${GARAGE_RPC_PORT}:3901" \
  -p "${GARAGE_WEB_PORT}:3902" \
  -p 3903:3903 \
  -v "${DATA_DIR}:/data" \
  -v /etc/garage/garage.toml:/etc/garage.toml \
  "${GARAGE_IMAGE}"

# ---------- Wait for Garage to start ----------
log "Waiting for Garage to be ready..."
if ! wait_for_port "${GARAGE_S3_PORT}" 30; then
  echo "ERROR: Garage failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

# Wait for Garage CLI to be responsive
if ! wait_for_garage 30; then
  echo "ERROR: Garage CLI not responding"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

# ---------- Configure cluster layout ----------
log "Configuring Garage cluster layout..."
NODE_ID=$(docker exec "${CONTAINER_NAME}" /garage node id 2>/dev/null | head -1 | cut -d'@' -f1)

if [[ -z "${NODE_ID}" ]]; then
  echo "ERROR: Could not get node ID"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

echo "Node ID: ${NODE_ID}"

# Assign node to layout
if ! docker exec "${CONTAINER_NAME}" /garage layout assign -z dc1 -c 1G "${NODE_ID}"; then
  echo "ERROR: Failed to assign node to layout"
  exit 1
fi

# Apply layout - try multiple versions if needed
APPLIED=false
for VERSION in 1 2 3 4 5; do
  if docker exec "${CONTAINER_NAME}" /garage layout apply --version "${VERSION}" 2>/dev/null; then
    APPLIED=true
    break
  fi
done

if [[ "${APPLIED}" != "true" ]]; then
  # Check if layout is already applied
  if docker exec "${CONTAINER_NAME}" /garage layout show 2>&1 | grep -q "No changes"; then
    echo "Layout already configured"
  else
    echo "WARNING: Could not apply layout automatically"
    echo "Run manually: docker exec garage /garage layout apply --version <next_version>"
  fi
fi

log "Cluster layout configured successfully"

# Wait for layout to be ready
sleep 2

# ---------- Create default key ----------
log "Creating default API key..."
KEY_OUTPUT=$(docker exec "${CONTAINER_NAME}" /garage key create default-key 2>&1 || echo "")

# Check if key already exists
if echo "${KEY_OUTPUT}" | grep -q "already exists"; then
  KEY_OUTPUT=$(docker exec "${CONTAINER_NAME}" /garage key info default-key 2>/dev/null || echo "")
fi

ACCESS_KEY=$(echo "${KEY_OUTPUT}" | grep -oP 'Key ID: \K[A-Z0-9]+' 2>/dev/null || echo "")
SECRET_KEY=$(echo "${KEY_OUTPUT}" | grep -oP 'Secret key: \K[a-f0-9]+' 2>/dev/null || echo "")

if [[ -z "${ACCESS_KEY}" ]]; then
  ACCESS_KEY="run: docker exec garage /garage key list"
fi
if [[ -z "${SECRET_KEY}" ]]; then
  SECRET_KEY="run: docker exec garage /garage key info default-key"
fi

# ---------- Create default bucket ----------
log "Creating default bucket..."
docker exec "${CONTAINER_NAME}" /garage bucket create default-bucket 2>/dev/null || true
docker exec "${CONTAINER_NAME}" /garage bucket allow --read --write --owner default-bucket --key default-key 2>/dev/null || true

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  Garage Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${GARAGE_VERSION}"
echo "S3 API port: ${GARAGE_S3_PORT}"
echo "RPC port: ${GARAGE_RPC_PORT}"
echo "Web port: ${GARAGE_WEB_PORT}"
echo "Admin port: 3903"
echo "Data: ${DATA_DIR}"
echo ""
echo "Default API Key:"
echo "  Access Key: ${ACCESS_KEY}"
echo "  Secret Key: ${SECRET_KEY}"
echo ""
echo "S3 Endpoint:"
echo "  http://${SERVER_IP}:${GARAGE_S3_PORT}"
echo ""
echo "Default Bucket: default-bucket"
echo ""
echo "AWS CLI example:"
echo "  aws --endpoint-url http://${SERVER_IP}:${GARAGE_S3_PORT} s3 ls s3://default-bucket/"
echo ""
echo "Create more buckets:"
echo "  docker exec ${CONTAINER_NAME} /garage bucket create mybucket"
echo "  docker exec ${CONTAINER_NAME} /garage bucket allow --read --write --owner mybucket --key default-key"
echo ""
echo "Config: /etc/garage/garage.toml"
echo ""
echo "Uninstall:"
echo "  sudo ./garage.sh --uninstall"
echo ""
