#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

PORTAINER_VERSION="2.33.2"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- install docker if not present ----------
if ! need_cmd docker; then
  log "Docker not found. Installing Docker..."

  # Install prerequisites
  apt-get update -y
  apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

  # Add Docker's official GPG key
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  # Set up the repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Install Docker Engine
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Start and enable Docker
  systemctl start docker
  systemctl enable docker

  log "Docker installed successfully"
else
  log "Docker already installed: $(docker --version)"
fi

# Verify Docker is running
if ! systemctl is-active --quiet docker; then
  log "Starting Docker service..."
  systemctl start docker
fi

# ---------- remove existing portainer if present ----------
if docker ps -a --format '{{.Names}}' | grep -q '^portainer$'; then
  log "Removing existing Portainer container..."
  docker stop portainer || true
  docker rm portainer || true
fi

# ---------- create portainer volume ----------
if ! docker volume ls --format '{{.Name}}' | grep -q '^portainer_data$'; then
  log "Creating Portainer data volume..."
  docker volume create portainer_data
else
  log "Portainer data volume already exists"
fi

# ---------- install portainer ----------
log "Installing Portainer CE ${PORTAINER_VERSION}..."
docker run -d \
  -p 8000:8000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:${PORTAINER_VERSION}

# ---------- wait for portainer to start ----------
log "Waiting for Portainer to start..."
sleep 5

# ---------- verify installation ----------
if docker ps --format '{{.Names}}' | grep -q '^portainer$'; then
  log "Done."
  echo ""
  echo "=========================================="
  echo "  Portainer Installation Complete!"
  echo "=========================================="
  echo ""
  echo "Version: Portainer CE ${PORTAINER_VERSION}"
  echo ""
  echo "Access Portainer at:"
  echo " - HTTPS: https://your-server-ip:9443"
  echo " - Edge Agent: port 8000"
  echo ""
  echo "Notes:"
  echo " - Create your admin account on first login"
  echo " - Data is persisted in 'portainer_data' volume"
  echo ""
else
  echo "ERROR: Portainer container failed to start"
  docker logs portainer
  exit 1
fi
