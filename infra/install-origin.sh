#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: sudo ./install-origin.sh media.example.com operator@example.com"
  exit 2
fi

DOMAIN="$1"
EMAIL="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx certbot python3-certbot-nginx ufw

install -d -o ubuntu -g ubuntu /srv/demoscene/releases
install -d -o ubuntu -g ubuntu /srv/demoscene/bootstrap/catalog/v1
install -d -o ubuntu -g ubuntu /srv/demoscene/bootstrap/media
ln -sfn /srv/demoscene/bootstrap /srv/demoscene/current

sed "s/__DOMAIN__/${DOMAIN}/g" "$SCRIPT_DIR/nginx/demoscene.conf" > /etc/nginx/sites-available/demoscene
ln -sfn /etc/nginx/sites-available/demoscene /etc/nginx/sites-enabled/demoscene
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl enable --now nginx

ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow "Nginx Full"
ufw --force enable

certbot --nginx \
  --non-interactive \
  --agree-tos \
  --redirect \
  --email "$EMAIL" \
  --domain "$DOMAIN"

systemctl reload nginx
echo "Origin ready at https://${DOMAIN}/health"

