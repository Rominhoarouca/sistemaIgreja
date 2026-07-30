#!/usr/bin/env bash
set -euo pipefail

# Precompress Flutter web build artifacts for nginx to serve precompressed files.
# Requires: brotli and gzip available on PATH.
# Usage: ./scripts/precompress_web.sh [build/web]

BUILD_DIR=${1:-build/web}
if [ ! -d "$BUILD_DIR" ]; then
  echo "Build directory not found: $BUILD_DIR"
  exit 1
fi

echo "Precompressing files in $BUILD_DIR ..."

# ttf/otf/svg incluídos porque Sora e Instrument Sans (assets/fonts) são
# empacotadas como asset — sem essas extensões aqui elas ficam sem par
# pré-comprimido e nginx_app.conf's brotli_static/gzip_static não tem o que servir.
TYPES=( -iname "*.js" -o -iname "*.css" -o -iname "*.html" -o -iname "*.json" \
        -o -iname "*.wasm" -o -iname "*.ttf" -o -iname "*.otf" -o -iname "*.svg" )

# Gzip
find "$BUILD_DIR" -type f \( "${TYPES[@]}" \) -print0 |
  xargs -0 -n1 -P4 -I{} sh -c 'gzip -9 -c "{}" > "{}.gz"'

# Brotli (melhor compressão) para os mesmos tipos
find "$BUILD_DIR" -type f \( "${TYPES[@]}" \) -print0 |
  xargs -0 -n1 -P4 -I{} sh -c 'brotli -q 11 -f -o "{}.br" "{}"'

# Optionally compress images to webp (not done here) — keep originals

echo "Precompression complete."
