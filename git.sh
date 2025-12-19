#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

TARGET_USER="${SUDO_USER:-}"
if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
  TARGET_USER="root"
fi
TARGET_HOME="$(eval echo "~${TARGET_USER}")"

# ---------- install git ----------
log "Installing Git..."
apt-get update -y
apt-get install -y git

# ---------- configure git ----------
log "Git installed: $(git --version)"

# Create global gitignore
log "Creating global .gitignore..."
cat > "${TARGET_HOME}/.gitignore_global" <<'EOF'
# OS
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# Logs
*.log

# Environment
.env
.env.local

# Dependencies
node_modules/
vendor/
__pycache__/
*.pyc
EOF

chown "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.gitignore_global"

# Configure git to use global gitignore
sudo -u "${TARGET_USER}" git config --global core.excludesfile "${TARGET_HOME}/.gitignore_global"

# Set some useful defaults
sudo -u "${TARGET_USER}" git config --global init.defaultBranch main
sudo -u "${TARGET_USER}" git config --global pull.rebase false
sudo -u "${TARGET_USER}" git config --global core.autocrlf input

log "Done."
echo ""
echo "=========================================="
echo "  Git Installation Complete!"
echo "=========================================="
echo ""
echo "Version: $(git --version)"
echo ""
echo "Configure your identity:"
echo "  git config --global user.name 'Your Name'"
echo "  git config --global user.email 'you@example.com'"
echo ""
echo "Global gitignore: ${TARGET_HOME}/.gitignore_global"
echo ""
