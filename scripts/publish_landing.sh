#!/usr/bin/env bash
# Publish Landing Page Docker image to Docker Hub.
#
# Usage:
#   bash scripts/publish_landing.sh [OPTIONS]
#
# Options:
#   --tag=<TAG>   Docker image tag (default: latest)
#
# Alternatively, use environment variables:
#   TAG=0.0.2 bash scripts/publish_landing.sh

set -euo pipefail

# ── Parse arguments ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag=*) TAG="${1#--tag=}"; shift ;;
    --tag)   TAG="$2";          shift 2 ;;
    *)       shift ;;
  esac
done

TAG=${TAG:-latest}

DOCKER_IMAGE="rominhoarouca/sistema-igreja-landing"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "================================================"
echo "  Publish Landing Page"
echo "  Image : $DOCKER_IMAGE:$TAG"
echo "================================================"

docker buildx build \
  --no-cache \
  --platform linux/amd64,linux/arm64 \
  -t "$DOCKER_IMAGE:$TAG" \
  -f "$ROOT_DIR/landingPage/Dockerfile" \
  "$ROOT_DIR/landingPage" \
  --push

echo ""
echo "✓ Published: $DOCKER_IMAGE:$TAG"
