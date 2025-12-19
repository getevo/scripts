#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- get timezone from argument or prompt ----------
TIMEZONE="${1:-}"

if [[ -z "${TIMEZONE}" ]]; then
  echo ""
  echo "Common timezones:"
  echo "  UTC"
  echo "  America/New_York"
  echo "  America/Los_Angeles"
  echo "  Europe/London"
  echo "  Europe/Paris"
  echo "  Asia/Tokyo"
  echo "  Asia/Singapore"
  echo "  Asia/Dubai"
  echo "  Asia/Tehran"
  echo "  Australia/Sydney"
  echo ""
  echo "List all: timedatectl list-timezones"
  echo ""
  read -p "Enter timezone: " TIMEZONE
fi

if [[ -z "${TIMEZONE}" ]]; then
  echo "ERROR: No timezone specified"
  exit 1
fi

# ---------- verify timezone exists ----------
if ! timedatectl list-timezones | grep -q "^${TIMEZONE}$"; then
  echo "ERROR: Invalid timezone '${TIMEZONE}'"
  echo "Use 'timedatectl list-timezones' to list valid options"
  exit 1
fi

# ---------- set timezone ----------
log "Setting timezone to ${TIMEZONE}..."
timedatectl set-timezone "${TIMEZONE}"

log "Done."
echo ""
echo "=========================================="
echo "  Timezone Configuration Complete!"
echo "=========================================="
echo ""
timedatectl
echo ""
