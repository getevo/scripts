#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# Default PHP version
DEFAULT_VERSION="8.3"

# ---------- get version ----------
PHP_VERSION="${1:-}"

if [[ -z "${PHP_VERSION}" ]]; then
  echo ""
  echo "Available versions: 7.4, 8.0, 8.1, 8.2, 8.3, 8.4"
  read -p "Enter PHP version [${DEFAULT_VERSION}]: " PHP_VERSION
  PHP_VERSION="${PHP_VERSION:-${DEFAULT_VERSION}}"
fi

# Validate version format
if ! [[ "${PHP_VERSION}" =~ ^[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Version must be in format X.Y (e.g., 8.3)"
  exit 1
fi

log "Installing PHP version: ${PHP_VERSION}"

# ---------- add ondrej php repository ----------
log "Adding PHP repository..."
apt-get update -y
apt-get install -y --no-install-recommends software-properties-common
add-apt-repository -y ppa:ondrej/php

# ---------- install php ----------
log "Installing PHP ${PHP_VERSION} with common extensions..."
apt-get update -y
apt-get install -y --no-install-recommends \
  php${PHP_VERSION} \
  php${PHP_VERSION}-cli \
  php${PHP_VERSION}-common \
  php${PHP_VERSION}-curl \
  php${PHP_VERSION}-mbstring \
  php${PHP_VERSION}-mysql \
  php${PHP_VERSION}-pgsql \
  php${PHP_VERSION}-xml \
  php${PHP_VERSION}-zip \
  php${PHP_VERSION}-gd \
  php${PHP_VERSION}-bcmath \
  php${PHP_VERSION}-intl \
  php${PHP_VERSION}-readline \
  php${PHP_VERSION}-opcache \
  php${PHP_VERSION}-fpm

# ---------- install composer ----------
log "Installing Composer..."
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

log "Done."
echo ""
echo "=========================================="
echo "  PHP Installation Complete!"
echo "=========================================="
echo ""
echo "PHP: $(php -v | head -1)"
echo "Composer: $(composer --version)"
echo ""
echo "Installed extensions:"
php -m | grep -E '^(curl|mbstring|mysql|pgsql|xml|zip|gd|bcmath|intl|opcache)$' | sort
echo ""
