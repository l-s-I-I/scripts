#!/bin/bash

set -e

if [[ "$EUID" -ne 0 ]]; then
  echo -e "\e[33mError: Please run as root with sudo.\e[0m"
  exit 1
fi

WP_DB_NAME=wordpress
WP_DB_ADMIN_USER=wpadmin

echo -e "\e[33mHOSTNAME:\e[0m"
read HOSTNAME

echo -e "\e[33mMySQL password for wpadmin user:\e[0m"
echo -e "> 8 chars, including numeric, mixed case, and special characters"
read -s MYSQL_WP_ADMIN_USER_PASSWORD

echo -e "\e[33mStarting system update and dependency installation...\e[0m"
apt-get update && apt-get -y upgrade && apt-get -y autoremove

apt-get install -y nginx mysql-server php-fpm php-mysql certbot python3-certbot-nginx

echo -e "\e[33mSystem update and dependency installation completed.\e[0m"

PHP_FPM_VERSION=$(php --version | grep -oP '^PHP \K[0-9]+\.[0-9]+' | head -1)
PHP_FPM_SOCKET="/run/php/php${PHP_FPM_VERSION}-fpm.sock"

cat > /etc/nginx/sites-available/$HOSTNAME <<EOF
server {
  listen 80;
  server_name $HOSTNAME;
  root /var/www/html/wordpress/blog;
  index index.php index.html index.htm;
  location / {
    try_files \$uri \$uri/ /index.php?\$args;
  }
  location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:$PHP_FPM_SOCKET;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
  }
}
EOF

ln -sf /etc/nginx/sites-available/$HOSTNAME /etc/nginx/sites-enabled/
systemctl reload nginx

echo -e "\e[33mConfiguring SSL certificate...\e[0m"
certbot --nginx -d $HOSTNAME --non-interactive --agree-tos -m your-email@example.com --redirect

echo -e "\e[33mSSL setup completed!\e[0m"

echo -e "\e[33mConfiguring MySQL for WordPress...\e[0m"
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${WP_DB_NAME};
CREATE USER '${WP_DB_ADMIN_USER}'@'localhost' IDENTIFIED BY '${MYSQL_WP_ADMIN_USER_PASSWORD}';
GRANT ALL ON ${WP_DB_NAME}.* TO '${WP_DB_ADMIN_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

echo -e "\e[33mInstalling WordPress 6.7.2...\e[0m"
sudo mkdir -p /var/www/html/wordpress/src
sudo mkdir -p /var/www/html/wordpress/blog
cd /var/www/html/wordpress/src
sudo wget https://wordpress.org/wordpress-6.7.2.tar.gz
sudo tar -xvf wordpress-6.7.2.tar.gz
sudo mv wordpress-6.7.2.tar.gz wordpress-`date "+%Y-%m-%d"`.tar.gz
sudo mv wordpress/* ../blog/
sudo chown -R www-data:www-data /var/www/html/wordpress/blog

echo -e "\e[33mWordPress 6.7.2 installation completed.\e[0m"

WP_SECURE_SALTS="$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)"
WP_CONFIG_FILE=/var/www/html/wordpress/blog/wp-config.php
cat > "${WP_CONFIG_FILE}" <<EOF
<?php

define( 'DB_NAME', '${WP_DB_NAME}' );
define( 'DB_USER', '${WP_DB_ADMIN_USER}' );
define( 'DB_PASSWORD', '${MYSQL_WP_ADMIN_USER_PASSWORD}' );
define( 'DB_HOST', 'localhost' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );
${WP_SECURE_SALTS}
\$table_prefix = 'wp_';
define( 'WP_DEBUG', false );
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}
require_once ABSPATH . 'wp-settings.php';
EOF

chown -R www-data:www-data "${WP_CONFIG_FILE}"

echo -e "\e[33mWordPress installation and SSL setup completed successfully!\e[0m"
