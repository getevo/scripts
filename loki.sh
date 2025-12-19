#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="loki"
DATA_DIR="/data/loki"
LOKI_PORT="${LOKI_PORT:-3100}"

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing Loki container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create directories ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p /etc/loki

# ---------- create loki config ----------
log "Creating Loki configuration..."
cat > /etc/loki/config.yml <<'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
    shared_store: filesystem

limits_config:
  retention_period: 168h
EOF

# ---------- run loki container ----------
log "Starting Loki container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${LOKI_PORT}:3100" \
  -v /etc/loki:/etc/loki \
  -v "${DATA_DIR}:/loki" \
  grafana/loki:latest \
  -config.file=/etc/loki/config.yml

# ---------- wait for loki to start ----------
log "Waiting for Loki to start..."
sleep 5

# ---------- get server ip ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  Loki Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "Port: ${LOKI_PORT}"
  echo "Data: ${DATA_DIR}"
  echo ""
  echo "API endpoint:"
  echo "  http://${SERVER_IP}:${LOKI_PORT}"
  echo ""
  echo "Add as Grafana datasource:"
  echo "  URL: http://loki:3100"
  echo ""
  echo "Config: /etc/loki/config.yml"
  echo ""
else
  echo "ERROR: Loki container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
