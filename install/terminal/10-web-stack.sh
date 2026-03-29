#!/usr/bin/env bash

log "Installing PHP and MySQL..."
sudo apt-get update -y
apt_install \
  php \
  php-cli \
  php-fpm \
  php-common \
  php-mbstring \
  php-xml \
  php-curl \
  php-gd \
  php-imagick \
  php-zip \
  php-bcmath \
  php-intl \
  php-mysql \
  php-pgsql \
  php-sqlite3 \
  php-redis \
  php-dom \
  php-opcache \
  php-soap \
  mysql-server

if command -v systemctl >/dev/null 2>&1; then
  log "Enabling MySQL..."
  sudo systemctl enable mysql || true
  sudo systemctl start mysql || true
fi

log "Setting empty MySQL root password..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY ''; FLUSH PRIVILEGES;" \
  || warn "Could not update the MySQL root user."

if command -v composer >/dev/null 2>&1; then
  log "Composer is already installed."
else
  log "Installing Composer..."
  php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  php composer-setup.php
  sudo mv composer.phar /usr/local/bin/composer
  rm -f composer-setup.php
fi

add_line_if_missing "export PATH=\"\$HOME/.config/composer/vendor/bin:\$PATH\"" "$TARGET_HOME/.bashrc"
add_line_if_missing "export PATH=\"\$HOME/.bun/bin:\$PATH\"" "$TARGET_HOME/.bashrc"
export PATH="$HOME/.config/composer/vendor/bin:$HOME/.bun/bin:$PATH"

log "Installing Valet prerequisites..."
apt_install network-manager libnss3-tools jq xsel

log "Installing valet-linux..."
composer global require cpriego/valet-linux

add_line_if_missing 'alias copy="xsel -b"' "$TARGET_HOME/.bashrc"
add_line_if_missing 'alias paste="xsel -b -o"' "$TARGET_HOME/.bashrc"
