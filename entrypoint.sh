#!/bin/sh
set -e

API_URL="${API_BASE_URL:-http://192.168.0.190/v1}"
echo "[entrypoint] Configurando API_BASE_URL: $API_URL"

find /usr/share/nginx/html -name "*.js" -exec \
  sed -i "s|__API_BASE_URL_PLACEHOLDER__|${API_URL}|g" {} \;

exec nginx -g 'daemon off;'
