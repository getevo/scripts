#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- install python3 ----------
log "Installing Python 3 with pip and venv..."
apt-get update -y
apt-get install -y --no-install-recommends \
  python3 \
  python3-pip \
  python3-venv \
  python3-dev \
  python3-setuptools \
  python3-wheel

# ---------- create symlinks if not exist ----------
if [[ ! -f /usr/bin/python ]] && [[ -f /usr/bin/python3 ]]; then
  log "Creating python symlink..."
  ln -sf /usr/bin/python3 /usr/bin/python
fi

if [[ ! -f /usr/bin/pip ]] && [[ -f /usr/bin/pip3 ]]; then
  log "Creating pip symlink..."
  ln -sf /usr/bin/pip3 /usr/bin/pip
fi

# ---------- upgrade pip ----------
log "Upgrading pip..."
python3 -m pip install --upgrade pip

log "Done."
echo ""
echo "=========================================="
echo "  Python Installation Complete!"
echo "=========================================="
echo ""
echo "Python: $(python3 --version)"
echo "pip: $(pip3 --version)"
echo ""
echo "Create virtual environment:"
echo "  python3 -m venv myenv"
echo "  source myenv/bin/activate"
echo ""
