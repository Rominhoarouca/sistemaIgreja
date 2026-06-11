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

# Gzip JS/CSS/HTML/JSON
find "$BUILD_DIR" -type f \( -iname "*.js" -o -iname "*.css" -o -iname "*.html" -o -iname "*.json" -o -iname "*.wasm" \) -print0 |
  xargs -0 -n1 -P4 -I{} sh -c 'gzip -9 -c "{}" > "{}.gz"'

# Brotli (better compression) for same types
find "$BUILD_DIR" -type f \( -iname "*.js" -o -iname "*.css" -o -iname "*.html" -o -iname "*.json" -o -iname "*.wasm" \) -print0 |
  xargs -0 -n1 -P4 -I{} sh -c 'brotli -q 11 -f -o "{}.br" "{}"'

# Optionally compress images to webp (not done here) — keep originals

echo "Precompression complete."
