#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- get parameters ----------
LOG_PATH="${1:-}"
ROTATE_DAYS="${2:-7}"
MAX_SIZE="${3:-100M}"

if [[ -z "${LOG_PATH}" ]]; then
  echo ""
  echo "Usage: $0 <log_path> [rotate_days] [max_size]"
  echo ""
  echo "Examples:"
  echo "  $0 /var/log/myapp/*.log"
  echo "  $0 /var/log/myapp/*.log 14"
  echo "  $0 /var/log/myapp/*.log 7 50M"
  echo ""
  read -p "Enter log path (e.g., /var/log/myapp/*.log): " LOG_PATH
  read -p "Keep logs for how many days? [7]: " ROTATE_DAYS
  read -p "Max size before rotation? [100M]: " MAX_SIZE
  ROTATE_DAYS="${ROTATE_DAYS:-7}"
  MAX_SIZE="${MAX_SIZE:-100M}"
fi

if [[ -z "${LOG_PATH}" ]]; then
  echo "ERROR: No log path specified"
  exit 1
fi

# ---------- install logrotate ----------
log "Installing logrotate..."
apt-get update -y
apt-get install -y logrotate

# ---------- create config name from path ----------
CONFIG_NAME=$(echo "${LOG_PATH}" | sed 's/[^a-zA-Z0-9]/_/g' | sed 's/__*/_/g' | sed 's/^_//' | sed 's/_$//')
CONFIG_FILE="/etc/logrotate.d/${CONFIG_NAME}"

# ---------- create logrotate config ----------
log "Creating logrotate config: ${CONFIG_FILE}"
cat > "${CONFIG_FILE}" <<EOF
${LOG_PATH} {
    daily
    rotate ${ROTATE_DAYS}
    size ${MAX_SIZE}
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
    sharedscripts
    postrotate
        # Add any post-rotation commands here
    endscript
}
EOF

# ---------- test config ----------
log "Testing logrotate configuration..."
if ! logrotate -d "${CONFIG_FILE}" 2>&1 | head -20; then
  echo "WARNING: Check configuration for issues"
fi

log "Done."
echo ""
echo "=========================================="
echo "  Logrotate Configuration Complete!"
echo "=========================================="
echo ""
echo "Log path: ${LOG_PATH}"
echo "Retention: ${ROTATE_DAYS} days"
echo "Max size: ${MAX_SIZE}"
echo "Config: ${CONFIG_FILE}"
echo ""
echo "Test rotation: logrotate -d ${CONFIG_FILE}"
echo "Force rotation: logrotate -f ${CONFIG_FILE}"
echo ""
