#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- get hostname from argument or prompt ----------
NEW_HOSTNAME="${1:-}"

if [[ -z "${NEW_HOSTNAME}" ]]; then
  echo ""
  echo "Current hostname: $(hostname)"
  echo ""
  read -p "Enter new hostname: " NEW_HOSTNAME
fi

if [[ -z "${NEW_HOSTNAME}" ]]; then
  echo "ERROR: No hostname specified"
  exit 1
fi

# ---------- validate hostname ----------
if ! [[ "${NEW_HOSTNAME}" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
  echo "ERROR: Invalid hostname '${NEW_HOSTNAME}'"
  echo "Hostname must start and end with alphanumeric, can contain hyphens"
  exit 1
fi

OLD_HOSTNAME=$(hostname)

# ---------- set hostname ----------
log "Setting hostname to ${NEW_HOSTNAME}..."
hostnamectl set-hostname "${NEW_HOSTNAME}"

# ---------- update /etc/hosts ----------
log "Updating /etc/hosts..."
if grep -q "${OLD_HOSTNAME}" /etc/hosts; then
  sed -i "s/${OLD_HOSTNAME}/${NEW_HOSTNAME}/g" /etc/hosts
fi

# Ensure new hostname is in hosts file
if ! grep -q "${NEW_HOSTNAME}" /etc/hosts; then
  echo "127.0.1.1 ${NEW_HOSTNAME}" >> /etc/hosts
fi

log "Done."
echo ""
echo "=========================================="
echo "  Hostname Configuration Complete!"
echo "=========================================="
echo ""
echo "Old hostname: ${OLD_HOSTNAME}"
echo "New hostname: ${NEW_HOSTNAME}"
echo ""
echo "Verify: hostname"
echo ""
