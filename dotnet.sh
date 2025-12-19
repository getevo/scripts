#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- check if already installed ----------
if need_cmd dotnet; then
  log ".NET SDK already installed: $(dotnet --version)"
  exit 0
fi

# ---------- install prerequisites ----------
log "Installing prerequisites..."
apt-get update -y
apt-get install -y --no-install-recommends wget

# ---------- add microsoft repository ----------
log "Adding Microsoft repository..."
wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O /tmp/packages-microsoft-prod.deb
dpkg -i /tmp/packages-microsoft-prod.deb
rm /tmp/packages-microsoft-prod.deb

# ---------- install dotnet sdk ----------
log "Installing .NET SDK 8.0..."
apt-get update -y
apt-get install -y dotnet-sdk-8.0

log "Done."
echo ""
echo "=========================================="
echo "  .NET SDK Installation Complete!"
echo "=========================================="
echo ""
echo ".NET SDK: $(dotnet --version)"
echo ""
echo "Create new project:"
echo "  dotnet new console -n MyApp"
echo "  cd MyApp && dotnet run"
echo ""
