#!/usr/bin/env bash
#
# prometheus.sh - Install Prometheus monitoring in Docker
#
# Usage:
#   sudo ./prometheus.sh                     # Interactive mode
#   sudo ./prometheus.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   PROMETHEUS_PORT     - Port to expose (default: 9090)
#   DATA_DIR            - Data directory (default: /data/prometheus)
#   PROMETHEUS_VERSION  - Image version (default: v2.48.1)
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
CONTAINER_NAME="prometheus"
DEFAULT_DATA_DIR="/data/prometheus"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-v2.48.1}"

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

# ---------- Root check ----------
if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- Uninstall mode ----------
if [[ "${1:-}" == "--uninstall" ]]; then
  log "Uninstalling Prometheus..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  if [[ -d "${DEFAULT_DATA_DIR}" ]]; then
    read -p "Remove data directory ${DEFAULT_DATA_DIR}? [y/N]: " REMOVE_DATA
    if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
      rm -rf "${DEFAULT_DATA_DIR}"
      log "Data directory removed"
    fi
  fi
  read -p "Remove config /etc/prometheus? [y/N]: " REMOVE_CONFIG
  if [[ "${REMOVE_CONFIG}" =~ ^[Yy]$ ]]; then
    rm -rf /etc/prometheus
    log "Config removed"
  fi
  log "Prometheus uninstalled"
  exit 0
fi

# ---------- Docker check ----------
if ! need_cmd docker; then
  echo "ERROR: Docker is not installed. Run docker.sh first."
  exit 1
fi

# ---------- Prompt for configuration ----------
echo ""
echo "Prometheus Setup"
echo "================"
echo ""

if [[ -z "${PROMETHEUS_PORT:-}" ]] || [[ "${PROMETHEUS_PORT}" == "9090" ]]; then
  read -p "Port [9090]: " PROMETHEUS_PORT_INPUT
  PROMETHEUS_PORT="${PROMETHEUS_PORT_INPUT:-9090}"
fi

if [[ -z "${DATA_DIR:-}" ]]; then
  read -p "Data directory [${DEFAULT_DATA_DIR}]: " DATA_DIR_INPUT
  DATA_DIR="${DATA_DIR_INPUT:-${DEFAULT_DATA_DIR}}"
else
  DATA_DIR="${DATA_DIR:-${DEFAULT_DATA_DIR}}"
fi

# ---------- Remove existing container ----------
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  log "Removing existing Prometheus container..."
  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true
fi

# ---------- Create directories ----------
log "Creating directories..."
mkdir -p "${DATA_DIR}"
mkdir -p /etc/prometheus

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

# ---------- Create Prometheus config ----------
log "Creating Prometheus configuration..."
cat > /etc/prometheus/prometheus.yml <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter (uncomment after installing node_exporter)
  # Install with: sudo apt-get install prometheus-node-exporter
  # - job_name: 'node'
  #   static_configs:
  #     - targets: ['${SERVER_IP}:9100']

  # Add your targets below:
  # - job_name: 'my-app'
  #   static_configs:
  #     - targets: ['${SERVER_IP}:8080']
EOF

# ---------- Run container ----------
log "Starting Prometheus ${PROMETHEUS_VERSION}..."
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=unless-stopped \
  -p "${PROMETHEUS_PORT}:9090" \
  -v /etc/prometheus:/etc/prometheus:ro \
  -v "${DATA_DIR}:/prometheus" \
  --health-cmd="wget -q --spider http://localhost:9090/-/healthy || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  prom/prometheus:${PROMETHEUS_VERSION} \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/prometheus \
  --web.enable-lifecycle \
  --web.enable-admin-api

# ---------- Wait for healthy ----------
log "Waiting for Prometheus to be ready..."
if ! wait_for_port "${PROMETHEUS_PORT}" 30; then
  echo "ERROR: Prometheus failed to start"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
  exit 1
fi

log "Done."
echo ""
echo "=========================================="
echo "  Prometheus Installation Complete!"
echo "=========================================="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Version: ${PROMETHEUS_VERSION}"
echo "Port: ${PROMETHEUS_PORT}"
echo "Data: ${DATA_DIR}"
echo ""
echo "Access:"
echo "  http://${SERVER_IP}:${PROMETHEUS_PORT}"
echo ""
echo "Config: /etc/prometheus/prometheus.yml"
echo ""
echo "Commands:"
echo "  Reload config: curl -X POST http://localhost:${PROMETHEUS_PORT}/-/reload"
echo "  Check health:  curl http://localhost:${PROMETHEUS_PORT}/-/healthy"
echo ""
echo "To monitor this server, install Node Exporter:"
echo "  sudo apt-get install prometheus-node-exporter"
echo "  Then uncomment the 'node' job in /etc/prometheus/prometheus.yml"
echo ""
echo "Uninstall:"
echo "  sudo ./prometheus.sh --uninstall"
echo ""
