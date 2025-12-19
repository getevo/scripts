#!/usr/bin/env bash
set -euo pipefail

# ---------- helpers ----------
log() { echo -e "\n==> $*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

# ---------- add ondrej php repository ----------
log "Adding PHP repository..."
apt-get update -y
apt-get install -y --no-install-recommends software-properties-common
add-apt-repository -y ppa:ondrej/php

# ---------- install php ----------
log "Installing PHP 8.3 with common extensions..."
apt-get update -y
apt-get install -y --no-install-recommends \
  php8.3 \
  php8.3-cli \
  php8.3-common \
  php8.3-curl \
  php8.3-mbstring \
  php8.3-mysql \
  php8.3-pgsql \
  php8.3-xml \
  php8.3-zip \
  php8.3-gd \
  php8.3-bcmath \
  php8.3-intl \
  php8.3-readline \
  php8.3-opcache \
  php8.3-fpm

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
