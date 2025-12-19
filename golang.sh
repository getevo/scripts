#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# Figure out which user to configure for
TARGET_USER="${SUDO_USER:-}"
if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
  TARGET_USER="root"
fi
TARGET_HOME="$(eval echo "~${TARGET_USER}")"

log "Target user: ${TARGET_USER} (${TARGET_HOME})"

# ---------- detect architecture ----------
ARCH=$(uname -m)
case "${ARCH}" in
  x86_64)  GOARCH="amd64" ;;
  aarch64) GOARCH="arm64" ;;
  armv6l)  GOARCH="armv6l" ;;
  i686)    GOARCH="386" ;;
  *)
    echo "Unsupported architecture: ${ARCH}"
    exit 1
    ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
log "Detected OS: ${OS}, Architecture: ${GOARCH}"

# ---------- get latest go version ----------
log "Fetching latest Go version..."
GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
log "Latest Go version: ${GO_VERSION}"

# ---------- remove existing go installation ----------
if [[ -d "/usr/local/go" ]]; then
  log "Removing existing Go installation from /usr/local/go..."
  rm -rf /usr/local/go
fi

# Also check if go is installed via other means
if need_cmd go; then
  EXISTING_GO=$(which go 2>/dev/null || true)
  if [[ -n "${EXISTING_GO}" && "${EXISTING_GO}" != "/usr/local/go/bin/go" ]]; then
    log "Warning: Go found at ${EXISTING_GO} (not managed by this script)"
  fi
fi

# ---------- download and install go ----------
DOWNLOAD_URL="https://go.dev/dl/${GO_VERSION}.${OS}-${GOARCH}.tar.gz"
log "Downloading Go from ${DOWNLOAD_URL}..."

curl -fsSL "${DOWNLOAD_URL}" -o /tmp/go.tar.gz
log "Extracting to /usr/local/go..."
tar -C /usr/local -xzf /tmp/go.tar.gz
rm /tmp/go.tar.gz

# ---------- set environment variables ----------
log "Configuring environment variables..."
BASHRC="${TARGET_HOME}/.bashrc"
PROFILE="${TARGET_HOME}/.profile"

# Environment block to add
ENV_BLOCK='
# Go environment variables
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin'

# Remove old Go environment config if exists
for FILE in "${BASHRC}" "${PROFILE}"; do
  if [[ -f "${FILE}" ]]; then
    # Remove existing Go config block
    sed -i '/# Go environment variables/,/export PATH=.*GOPATH\/bin/d' "${FILE}"
  fi
done

# Add to .bashrc if it exists
if [[ -f "${BASHRC}" ]]; then
  if ! grep -q "GOROOT=/usr/local/go" "${BASHRC}"; then
    echo "${ENV_BLOCK}" >> "${BASHRC}"
    log "Added Go environment to ${BASHRC}"
  fi
  chown "${TARGET_USER}:${TARGET_USER}" "${BASHRC}"
fi

# Add to .profile as well for login shells
if [[ -f "${PROFILE}" ]]; then
  if ! grep -q "GOROOT=/usr/local/go" "${PROFILE}"; then
    echo "${ENV_BLOCK}" >> "${PROFILE}"
    log "Added Go environment to ${PROFILE}"
  fi
  chown "${TARGET_USER}:${TARGET_USER}" "${PROFILE}"
fi

# Create GOPATH directory
GOPATH_DIR="${TARGET_HOME}/go"
if [[ ! -d "${GOPATH_DIR}" ]]; then
  mkdir -p "${GOPATH_DIR}"
  chown "${TARGET_USER}:${TARGET_USER}" "${GOPATH_DIR}"
  log "Created GOPATH directory: ${GOPATH_DIR}"
fi

# ---------- verify installation ----------
log "Verifying installation..."
export GOROOT=/usr/local/go
export PATH=$PATH:$GOROOT/bin
GO_INSTALLED_VERSION=$(/usr/local/go/bin/go version)

log "Done."
echo ""
echo "=========================================="
echo "  Go Installation Complete!"
echo "=========================================="
echo ""
echo "Installed: ${GO_INSTALLED_VERSION}"
echo ""
echo "Notes:"
echo " - Run 'source ~/.bashrc' or log out and back in to apply changes"
echo " - GOROOT: /usr/local/go"
echo " - GOPATH: ${GOPATH_DIR}"
echo " - Verify with: go version"
echo ""
