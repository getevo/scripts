#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

TARGET_USER="${SUDO_USER:-}"
if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
  TARGET_USER="root"
fi

# ---------- check if docker already installed ----------
if need_cmd docker; then
  log "Docker already installed: $(docker --version)"
  log "Docker Compose: $(docker compose version 2>/dev/null || echo 'not installed')"
  exit 0
fi

# ---------- install prerequisites ----------
log "Installing prerequisites..."
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# ---------- add docker gpg key ----------
log "Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# ---------- add docker repository ----------
log "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# ---------- install docker ----------
log "Installing Docker CE..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ---------- start docker ----------
log "Starting Docker service..."
systemctl start docker
systemctl enable docker

# ---------- add user to docker group ----------
if [[ "${TARGET_USER}" != "root" ]]; then
  log "Adding ${TARGET_USER} to docker group..."
  usermod -aG docker "${TARGET_USER}"
fi

log "Done."
echo ""
echo "=========================================="
echo "  Docker Installation Complete!"
echo "=========================================="
echo ""
echo "Docker: $(docker --version)"
echo "Compose: $(docker compose version)"
echo ""
echo "Notes:"
echo " - Log out and back in for group changes to apply"
echo " - Test with: docker run hello-world"
echo ""
