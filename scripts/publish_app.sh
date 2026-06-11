#!/usr/bin/env bash
# Publish Flutter Web PWA to Docker Hub.
#
# Usage:
#   bash scripts/publish_app.sh [OPTIONS]
#
# Options:
#   --tag=<TAG>               Docker image tag (default: latest)
#   --api_base_url=<URL>      API base URL baked into the web build
#                             (default: __API_BASE_URL_PLACEHOLDER__)
#
# Alternatively, use environment variables:
#   TAG=0.0.2 API_BASE_URL="https://..." bash scripts/publish_app.sh

set -euo pipefail

# ── Parse arguments ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag=*)         TAG="${1#--tag=}";              shift ;;
    --tag)           TAG="$2";                       shift 2 ;;
    --api_base_url=*) API_BASE_URL="${1#--api_base_url=}"; shift ;;
    --api_base_url)  API_BASE_URL="$2";              shift 2 ;;
    *)               shift ;;
  esac
done

TAG=${TAG:-latest}
API_BASE_URL=${API_BASE_URL:-__API_BASE_URL_PLACEHOLDER__}

DOCKER_IMAGE="rominhoarouca/sistema-igreja-app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "================================================"
echo "  Publish App"
echo "  Image : $DOCKER_IMAGE:$TAG"
echo "  API   : $API_BASE_URL"
echo "================================================"

# ── 1. Flutter build ────────────────────────────────────────────────────────────
echo ""
echo "→ [1/3] Building Flutter web..."
cd "$ROOT_DIR"
flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL"

# ── 2. Precompress ─────────────────────────────────────────────────────────────
echo ""
echo "→ [2/3] Precompressing assets..."
bash "$SCRIPT_DIR/precompress_web.sh" build/web

# ── 3. Docker buildx ──────────────────────────────────────────────────────────
echo ""
echo "→ [3/3] Building and pushing Docker image: $DOCKER_IMAGE:$TAG"
docker buildx build \
  --no-cache \
  --platform linux/amd64,linux/arm64 \
  -t "$DOCKER_IMAGE:$TAG" \
  -f Dockerfile.web \
  . \
  --push

echo ""
echo "✓ Published: $DOCKER_IMAGE:$TAG"
