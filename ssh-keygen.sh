#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# This script can run as regular user
TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME="$(eval echo "~${TARGET_USER}")"
SSH_DIR="${TARGET_HOME}/.ssh"

# ---------- install prerequisites ----------
if ! need_cmd ssh-keygen; then
  log "Installing OpenSSH client..."
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: ssh-keygen not found. Please run with sudo to install openssh-client."
    exit 1
  fi
  apt-get update -y
  apt-get install -y openssh-client
fi

# ---------- prompt for configuration ----------
echo ""
echo "SSH Key Generator"
echo "================="
echo ""

# Key type
if [[ -z "${SSH_KEY_TYPE:-}" ]]; then
  echo "Key types:"
  echo "  1) ed25519 (recommended by GitHub/GitLab, modern, secure)"
  echo "  2) rsa (4096-bit, for older systems)"
  echo "  3) ecdsa (elliptic curve)"
  echo ""
  read -p "Select key type [1]: " KEY_TYPE_CHOICE
  case "${KEY_TYPE_CHOICE:-1}" in
    1|"") SSH_KEY_TYPE="ed25519" ;;
    2) SSH_KEY_TYPE="rsa" ;;
    3) SSH_KEY_TYPE="ecdsa" ;;
    *) SSH_KEY_TYPE="ed25519" ;;
  esac
fi

# Key name
DEFAULT_KEY_NAME="id_${SSH_KEY_TYPE}"
if [[ -z "${SSH_KEY_NAME:-}" ]]; then
  read -p "Key name [${DEFAULT_KEY_NAME}]: " SSH_KEY_NAME
  SSH_KEY_NAME="${SSH_KEY_NAME:-${DEFAULT_KEY_NAME}}"
fi

KEY_PATH="${SSH_DIR}/${SSH_KEY_NAME}"

# Check if key already exists
if [[ -f "${KEY_PATH}" ]]; then
  echo ""
  echo "WARNING: Key already exists at ${KEY_PATH}"
  read -p "Overwrite? [y/N]: " OVERWRITE
  if [[ ! "${OVERWRITE}" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# Comment (usually email)
if [[ -z "${SSH_KEY_COMMENT:-}" ]]; then
  DEFAULT_COMMENT="${TARGET_USER}@$(hostname)"
  read -p "Comment/Email [${DEFAULT_COMMENT}]: " SSH_KEY_COMMENT
  SSH_KEY_COMMENT="${SSH_KEY_COMMENT:-${DEFAULT_COMMENT}}"
fi

# Passphrase
if [[ -z "${SSH_KEY_PASSPHRASE+x}" ]]; then
  echo ""
  echo "Passphrase protects your private key (recommended for security)."
  echo "Leave empty for no passphrase."
  while true; do
    read -s -p "Passphrase: " SSH_KEY_PASSPHRASE
    echo ""
    if [[ -z "${SSH_KEY_PASSPHRASE}" ]]; then
      read -p "No passphrase set. Continue without passphrase? [Y/n]: " NO_PASS_CONFIRM
      if [[ "${NO_PASS_CONFIRM}" =~ ^[Nn]$ ]]; then
        continue
      fi
      break
    else
      read -s -p "Confirm passphrase: " SSH_KEY_PASSPHRASE_CONFIRM
      echo ""
      if [[ "${SSH_KEY_PASSPHRASE}" != "${SSH_KEY_PASSPHRASE_CONFIRM}" ]]; then
        echo "Passphrases do not match. Please try again."
        continue
      fi
      break
    fi
  done
fi

# ---------- create .ssh directory ----------
log "Creating SSH directory..."
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

# ---------- generate key ----------
log "Generating ${SSH_KEY_TYPE} key..."

KEY_ARGS="-t ${SSH_KEY_TYPE} -C \"${SSH_KEY_COMMENT}\" -f \"${KEY_PATH}\" -N \"${SSH_KEY_PASSPHRASE}\""

if [[ "${SSH_KEY_TYPE}" == "rsa" ]]; then
  KEY_ARGS="-t rsa -b 4096 -C \"${SSH_KEY_COMMENT}\" -f \"${KEY_PATH}\" -N \"${SSH_KEY_PASSPHRASE}\""
fi

eval ssh-keygen ${KEY_ARGS}

# Fix ownership if running as root
if [[ "${EUID}" -eq 0 ]] && [[ -n "${SUDO_USER:-}" ]]; then
  chown -R "${SUDO_USER}:${SUDO_USER}" "${SSH_DIR}"
fi

# ---------- set permissions ----------
chmod 600 "${KEY_PATH}"
chmod 644 "${KEY_PATH}.pub"

log "Done."
echo ""
echo "=========================================="
echo "  SSH Key Generated!"
echo "=========================================="
echo ""
echo "Key type: ${SSH_KEY_TYPE}"
echo "Private key: ${KEY_PATH}"
echo "Public key: ${KEY_PATH}.pub"
echo "Comment: ${SSH_KEY_COMMENT}"
echo ""
echo "=========================================="
echo "  Your Public Key (copy this):"
echo "=========================================="
echo ""
cat "${KEY_PATH}.pub"
echo ""
echo "=========================================="
echo ""
echo "To copy to a remote server:"
echo "  ssh-copy-id -i ${KEY_PATH}.pub user@hostname"
echo ""
echo "To add to SSH agent:"
echo "  eval \$(ssh-agent -s)"
echo "  ssh-add ${KEY_PATH}"
echo ""
echo "Add this to GitHub/GitLab:"
echo "  cat ${KEY_PATH}.pub | xclip -selection clipboard"
echo "  # or just copy the public key shown above"
echo ""
