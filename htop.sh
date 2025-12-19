#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- install monitoring tools ----------
log "Installing system monitoring tools..."
apt-get update -y
apt-get install -y --no-install-recommends \
  htop \
  iotop \
  iftop \
  ncdu \
  dstat \
  sysstat \
  net-tools \
  lsof \
  strace \
  tcpdump \
  mtr-tiny \
  tree \
  jq

log "Done."
echo ""
echo "=========================================="
echo "  Monitoring Tools Installation Complete!"
echo "=========================================="
echo ""
echo "Installed tools:"
echo "  htop    - Interactive process viewer"
echo "  iotop   - I/O monitor (run as root)"
echo "  iftop   - Network bandwidth monitor"
echo "  ncdu    - Disk usage analyzer"
echo "  dstat   - System resource statistics"
echo "  iostat  - I/O statistics (from sysstat)"
echo "  vmstat  - Virtual memory statistics"
echo "  netstat - Network statistics"
echo "  lsof    - List open files"
echo "  strace  - System call tracer"
echo "  tcpdump - Network packet analyzer"
echo "  mtr     - Network diagnostic tool"
echo "  tree    - Directory listing"
echo "  jq      - JSON processor"
echo ""
