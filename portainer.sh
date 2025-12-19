#!/usr/bin/env bash
#
# portainer.sh - Install Portainer CE in Docker
#
# Usage:
#   sudo ./portainer.sh                     # Interactive mode
#   sudo ./portainer.sh --uninstall         # Remove container and optionally data
#
# Environment Variables:
#   PORTAINER_VERSION  - Image version (default: 2.27.3)
#   PORTAINER_PORT     - HTTPS port (default: 9443)
#
# Note: This script configures Docker with DOCKER_MIN_API_VERSION=1.24
#       to ensure compatibility with Portainer and Traefik.
#
set -euo pipefail
trap 'echo "ERROR: Script failed at line $LINENO. Command: $BASH_COMMAND" >&2; exit 1' ERR

# ---------- Configuration ----------
PORTAINER_VERSION="${PORTAINER_VERSION:-2.27.3}"
PORTAINER_PORT="${PORTAINER_PORT:-9443}"

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
  log "Uninstalling Portainer..."
  docker stop portainer 2>/dev/null || true
  docker rm portainer 2>/dev/null || true
  read -p "Remove Portainer data volume? [y/N]: " REMOVE_DATA
  if [[ "${REMOVE_DATA}" =~ ^[Yy]$ ]]; then
    docker volume rm portainer_data 2>/dev/null || true
    log "Data volume removed"
  fi
  log "Portainer uninstalled"
  exit 0
fi

# ---------- Install Docker if not present ----------
if ! need_cmd docker; then
  log "Docker not found. Installing Docker..."

  apt-get update -y
  apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl start docker
  systemctl enable docker

  log "Docker installed successfully"
else
  log "Docker already installed: $(docker --version)"
fi

# ---------- Configure Docker API version for Portainer/Traefik compatibility ----------
log "Configuring Docker API version for Portainer compatibility..."
DOCKER_OVERRIDE_DIR="/etc/systemd/system/docker.service.d"
DOCKER_OVERRIDE_FILE="${DOCKER_OVERRIDE_DIR}/override.conf"

if [[ ! -f "${DOCKER_OVERRIDE_FILE}" ]] || ! grep -q "DOCKER_MIN_API_VERSION" "${DOCKER_OVERRIDE_FILE}" 2>/dev/null; then
  mkdir -p "${DOCKER_OVERRIDE_DIR}"
  cat > "${DOCKER_OVERRIDE_FILE}" <<'EOF'
[Service]
Environment=DOCKER_MIN_API_VERSION=1.24
EOF

  log "Reloading Docker daemon..."
  systemctl daemon-reload
  systemctl restart docker

  log "Docker API version configured (DOCKER_MIN_API_VERSION=1.24)"
else
  log "Docker API version already configured"
fi

# Verify Docker is running
if ! systemctl is-active --quiet docker; then
  log "Starting Docker service..."
  systemctl start docker
fi

# ---------- Prompt for configuration ----------
echo ""
echo "Portainer Setup"
echo "==============="
echo ""

if [[ -z "${PORTAINER_PORT:-}" ]] || [[ "${PORTAINER_PORT}" == "9443" ]]; then
  read -p "HTTPS Port [9443]: " PORTAINER_PORT_INPUT
  PORTAINER_PORT="${PORTAINER_PORT_INPUT:-9443}"
fi

# ---------- Remove existing Portainer if present ----------
if docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
  log "Removing existing Portainer container..."
  docker stop portainer 2>/dev/null || true
  docker rm portainer 2>/dev/null || true
fi

# ---------- Create Portainer volume ----------
if ! docker volume ls --format '{{.Name}}' | grep -q '^portainer_data$'; then
  log "Creating Portainer data volume..."
  docker volume create portainer_data
else
  log "Portainer data volume already exists"
fi

# ---------- Install Portainer ----------
log "Installing Portainer CE ${PORTAINER_VERSION}..."
docker run -d \
  -p 8000:8000 \
  -p "${PORTAINER_PORT}:9443" \
  --name portainer \
  --restart=unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  --health-cmd="wget -q --spider https://localhost:9443 --no-check-certificate || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  portainer/portainer-ce:${PORTAINER_VERSION}

# ---------- Wait for Portainer to start ----------
log "Waiting for Portainer to be ready..."
if ! wait_for_port "${PORTAINER_PORT}" 30; then
  echo "ERROR: Portainer failed to start"
  docker logs portainer 2>&1 | tail -20
  exit 1
fi

# ---------- Get server IP ----------
SERVER_IP=$(hostname -I | awk '{print $1}')

log "Done."
echo ""
echo "=========================================="
echo "  Portainer Installation Complete!"
echo "=========================================="
echo ""
echo "Version: Portainer CE ${PORTAINER_VERSION} (LTS)"
echo "Port: ${PORTAINER_PORT}"
echo ""
echo "Access Portainer at:"
echo "  https://${SERVER_IP}:${PORTAINER_PORT}"
echo ""
echo "Edge Agent port: 8000"
echo ""
echo "Notes:"
echo "  - Create your admin account on first login"
echo "  - Data is persisted in 'portainer_data' volume"
echo "  - Docker API configured with DOCKER_MIN_API_VERSION=1.24"
echo ""
echo "Uninstall:"
echo "  sudo ./portainer.sh --uninstall"
echo ""
