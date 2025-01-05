#!/bin/bash
set -e

# Usage
# ./ssl.sh $HOSTNAME
# e.g. ./ssl.sh mydomain.com
#
# LetsEncrypt will get SSL cert for $HOSTNAME
# LetsEncrypt will also modify the nginx config
#
# Usage:
# sudo bash -c "$(curl -sS https://raw.githubusercontent.com/pietrorea/scripts/refs/heads/master/letsencrypt/ssl.sh)"
#

if [[ "$EUID" -ne 0 ]]; then
  echo "Error: Please run as root with sudo."
  exit
fi

echo "HOSTNAME:"
read HOSTNAME
echo

snap install core
snap refresh core
apt-get remove certbot
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
certbot certonly --nginx -d $HOSTNAME