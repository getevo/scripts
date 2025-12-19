#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# Figure out which user to configure screen + shell for
TARGET_USER="${SUDO_USER:-}"
if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
  # fallback: configure for root if no sudo user
  TARGET_USER="root"
fi
TARGET_HOME="$(eval echo "~${TARGET_USER}")"

log "Target user: ${TARGET_USER} (${TARGET_HOME})"

# ---------- base packages ----------
log "Installing prerequisites (curl, gnupg, locales, screen, nano, terminfo)..."
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates curl gnupg locales screen nano ncurses-term

# ---------- UTF-8 locale ----------
log "Ensuring UTF-8 locale (en_US.UTF-8)..."
if ! locale -a | grep -qi '^en_US\.utf8$'; then
  sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
  locale-gen
fi
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# ---------- Node.js 24 ----------
NODE_MAJOR_REQUIRED=24
INSTALL_NODE=true

if need_cmd node; then
  NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
  if [[ "${NODE_VERSION}" -ge "${NODE_MAJOR_REQUIRED}" ]]; then
    log "Node.js ${NODE_MAJOR_REQUIRED}+ already installed (found v$(node -v | sed 's/v//'))"
    INSTALL_NODE=false
  else
    log "Node.js found but version $(node -v) is older than v${NODE_MAJOR_REQUIRED}"
  fi
fi

if [[ "${INSTALL_NODE}" == "true" ]]; then
  log "Installing Node.js ${NODE_MAJOR_REQUIRED} (NodeSource)..."
  curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR_REQUIRED}.x | bash -
  apt-get install -y nodejs
fi

log "Node version: $(node -v)"
log "npm version: $(npm -v)"

# ---------- Claude Code ----------
INSTALL_CLAUDE=true

if sudo -u "${TARGET_USER}" bash -c 'command -v claude >/dev/null 2>&1'; then
  log "Claude Code already installed"
  INSTALL_CLAUDE=false
fi

if [[ "${INSTALL_CLAUDE}" == "true" ]]; then
  log "Installing Claude Code (official installer)..."
  sudo -u "${TARGET_USER}" bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'
fi

# ---------- screen config: UTF-8 + 256 colors ----------
log "Configuring GNU screen for UTF-8 + 256 colors..."
SCREENRC="${TARGET_HOME}/.screenrc"

cat > "${SCREENRC}" <<'EOF'
# --- UTF-8 ---
defutf8 on
utf8 on
encoding utf8 utf8

# --- 256 colors ---
# Use a 256-color term inside screen (requires ncurses-term on many distros)
term screen-256color

# Make sure screen understands xterm-256color capabilities when you attach from such terminals
termcapinfo xterm-256color 'Co#256:AB=\E[48;5;%dm:AF=\E[38;5;%dm'
defbce on

# Nice-to-have
startup_message off
vbell off
EOF

chown "${TARGET_USER}:${TARGET_USER}" "${SCREENRC}"

# ---------- shell config: TERM + cl alias ----------
log "Adding TERM=xterm-256color and 'cl' alias to ~/.bashrc..."
BASHRC="${TARGET_HOME}/.bashrc"

# Add TERM setup if not present
if [[ -f "${BASHRC}" ]] && ! grep -q "SCREEN_UTF8_256_SETUP" "${BASHRC}"; then
  cat >> "${BASHRC}" <<'EOF'

# SCREEN_UTF8_256_SETUP: ensure a 256-color terminal when using screen
# (Your terminal emulator must support 256 colors too.)
export TERM=${TERM:-xterm-256color}
EOF
fi

# Add 'cl' alias if not present
if [[ -f "${BASHRC}" ]] && ! grep -q "alias cl=" "${BASHRC}"; then
  cat >> "${BASHRC}" <<'EOF'

# cl: shortcut for Claude Code with permissions skip
alias cl='claude --dangerously-skip-permissions'
EOF
fi

chown "${TARGET_USER}:${TARGET_USER}" "${BASHRC}"

log "Done."
echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Notes:"
echo " - Re-login (or 'source ~/.bashrc') for changes to fully apply."
echo " - Start screen with: screen -U (or just 'screen' after this config)."
echo " - Use 'cl' command to run Claude Code with --dangerously-skip-permissions"
echo " - Verify inside screen: echo \$TERM  (should show screen-256color)"
echo " - Verify UTF-8: printf '\342\234\223\n'"
echo ""
