#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

CONTAINER_NAME="prometheus"
DATA_DIR="/data/prometheus"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"

# ---------- check docker ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing Prometheus container..."
  docker stop "${CONTAINER_NAME}" || true
  docker rm "${CONTAINER_NAME}" || true
fi

# ---------- create directories ----------
log "Creating data directory: ${DATA_DIR}"
mkdir -p "${DATA_DIR}"
mkdir -p /etc/prometheus

# ---------- create prometheus config ----------
log "Creating Prometheus configuration..."
cat > /etc/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['host.docker.internal:9100']
EOF

# ---------- run prometheus container ----------
log "Starting Prometheus container..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  -p "${PROMETHEUS_PORT}:9090" \
  -v /etc/prometheus:/etc/prometheus \
  -v "${DATA_DIR}:/prometheus" \
  --add-host=host.docker.internal:host-gateway \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus \
  --web.enable-lifecycle

# ---------- wait for prometheus to start ----------
log "Waiting for Prometheus to start..."
sleep 5

# ---------- get server ip ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

# ---------- verify ----------
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  Prometheus Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Container: ${CONTAINER_NAME}"
  echo "Port: ${PROMETHEUS_PORT}"
  echo "Data: ${DATA_DIR}"
  echo ""
  echo "Access:"
  echo "  http://${SERVER_IP}:${PROMETHEUS_PORT}"
  echo ""
  echo "Config: /etc/prometheus/prometheus.yml"
  echo "Reload config: curl -X POST http://localhost:${PROMETHEUS_PORT}/-/reload"
  echo ""
else
  echo "ERROR: Prometheus container failed to start"
  docker logs "${CONTAINER_NAME}"
  exit 1
fi
