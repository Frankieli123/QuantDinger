#!/bin/sh
set -e

# Replace BACKEND_HOST in nginx config
BACKEND_HOST=${BACKEND_HOST:-backend}
echo "Configuring nginx with BACKEND_HOST=$BACKEND_HOST"

sed -i "s|\${BACKEND_HOST}|$BACKEND_HOST|g" /etc/nginx/conf.d/default.conf

# Start nginx
exec nginx -g 'daemon off;'
