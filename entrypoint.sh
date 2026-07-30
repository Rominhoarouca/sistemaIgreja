#!/bin/sh
set -e

ROOT=/usr/share/nginx/html
PLACEHOLDER=__API_BASE_URL_PLACEHOLDER__

API_URL="${API_BASE_URL:-http://192.168.0.190/v1}"

# O `flutter build web` já gera .br/.gz ao lado de cada arquivo, e o nginx os
# serve via brotli_static/gzip_static. Reescrever um .js sem regerar esses pares
# faria o nginx servir a versão pré-comprimida antiga — ou seja, a URL de API
# errada. Por isso a substituição só acontece em quem realmente tem o
# placeholder, e cada arquivo tocado é recomprimido em seguida.
#
# Hoje a URL da API é fixada em tempo de build (--dart-define), então o
# placeholder não existe e este bloco não faz nada. Ele fica como rede de
# segurança para o dia em que a substituição em runtime voltar a ser usada.
TOUCHED=$(grep -rl "$PLACEHOLDER" "$ROOT" --include='*.js' 2>/dev/null || true)

if [ -n "$TOUCHED" ]; then
  echo "[entrypoint] Configurando API_BASE_URL: $API_URL"
  for f in $TOUCHED; do
    sed -i "s|$PLACEHOLDER|${API_URL}|g" "$f"
    gzip -9 -k -f "$f"
    brotli -q 11 -f -o "$f.br" "$f"
    echo "[entrypoint]   recomprimido: $f"
  done
else
  echo "[entrypoint] API_BASE_URL fixada no build; nada a substituir."
fi

exec nginx -g 'daemon off;'
