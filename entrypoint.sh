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
# A imagem publicada (publishAPP, sem --api_base_url) sai do build com o
# placeholder de propósito: a URL real vem da env var API_BASE_URL deste
# container, resolvida aqui. Builds locais (docker-compose) fixam a URL em
# tempo de build via --dart-define, então nesse caso o placeholder não existe
# e este bloco não faz nada.
#
# `find -exec grep` no lugar de `grep -r --include`: a imagem roda BusyBox, cujo
# grep não aceita `--include` — com ele a busca falhava calada (redirecionada
# para /dev/null) e a substituição nunca rodava.
TOUCHED=$(find "$ROOT" -name '*.js' -exec grep -l "$PLACEHOLDER" {} \; 2>/dev/null || true)

if [ -n "$TOUCHED" ]; then
  echo "[entrypoint] Configurando API_BASE_URL: $API_URL"
  for f in $TOUCHED; do
    sed -i "s|$PLACEHOLDER|${API_URL}|g" "$f"
    gzip -9 -k -f "$f"
    # Qualidade 9, não 11: -q11 no main.dart.js (5+ MB) leva ~20s, atrasando o
    # nginx subir a cada boot/restart do container. 11 só compensa quando roda
    # uma vez só no build (ver Dockerfile.web/build-web); em runtime, a cada
    # start, 9 chega perto do tamanho por uma fração do tempo.
    brotli -q 9 -f -o "$f.br" "$f"
    echo "[entrypoint]   recomprimido: $f"
  done
else
  echo "[entrypoint] API_BASE_URL fixada no build; nada a substituir."
fi

exec nginx -g 'daemon off;'
