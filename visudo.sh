#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# Get the user who invoked sudo
TARGET_USER="${SUDO_USER:-}"
if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
  echo "ERROR: Cannot determine the target user."
  echo "Please run with: sudo $0"
  exit 1
fi

# Verify user exists
if ! id "${TARGET_USER}" &>/dev/null; then
  echo "ERROR: User '${TARGET_USER}' does not exist"
  exit 1
fi

log "Adding NOPASSWD sudo access for user: ${TARGET_USER}"

# ---------- create sudoers file ----------
SUDOERS_FILE="/etc/sudoers.d/${TARGET_USER}-nopasswd"
SUDOERS_CONTENT="${TARGET_USER} ALL=(ALL) NOPASSWD: ALL"

# Write to temp file first
TEMP_FILE=$(mktemp)
echo "${SUDOERS_CONTENT}" > "${TEMP_FILE}"

# Validate syntax
if ! visudo -c -f "${TEMP_FILE}" &>/dev/null; then
  echo "ERROR: Invalid sudoers syntax"
  rm -f "${TEMP_FILE}"
  exit 1
fi

# Move to sudoers.d
mv "${TEMP_FILE}" "${SUDOERS_FILE}"
chmod 0440 "${SUDOERS_FILE}"
chown root:root "${SUDOERS_FILE}"

log "Done."
echo ""
echo "=========================================="
echo "  Sudoers Configuration Complete!"
echo "=========================================="
echo ""
echo "User '${TARGET_USER}' can now run sudo without password."
echo ""
echo "Config file: ${SUDOERS_FILE}"
echo ""
