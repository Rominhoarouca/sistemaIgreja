#!/bin/bash
# Build Flutter web app and create Docker image
# Usage: bash build-app.sh [API_URL]
# Example: bash build-app.sh http://localhost/v1

set -e

API_URL="${1:-http://192.168.0.190/v1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Building Flutter Web App"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "API URL: $API_URL"
echo ""

# Step 1: Check if Flutter is available locally
if command -v flutter &> /dev/null; then
    echo "✓ Flutter found locally, building with local Flutter..."
    echo ""
    
    # Step 1a: Clean previous build
    echo "→ Cleaning previous build..."
    rm -rf "$SCRIPT_DIR/build/web"
    
    # Step 1b: Get dependencies
    echo "→ Getting Flutter dependencies..."
    cd "$SCRIPT_DIR"
    flutter pub get
    
    # Step 1c: Build web
    echo "→ Building Flutter web..."
    cd "$SCRIPT_DIR"
    flutter build web --release --dart-define=API_BASE_URL="$API_URL"
    
else
    echo "⚠ Flutter not found locally, using Docker image..."
    echo ""
    
    # Use Docker to build
    docker run --rm \
        -v "$SCRIPT_DIR:/app" \
        -w /app \
        cirrusci/flutter:latest \
        bash -c "
            set -e
            echo '→ Cleaning previous build...'
            rm -rf /app/build/web
            
            echo '→ Getting Flutter dependencies...'
            flutter pub get
            
            echo '→ Building Flutter web...'
            flutter build web --release --dart-define=API_BASE_URL='$API_URL'
        "
fi

# Step 4: Build Docker image
echo ""
echo "→ Building Docker image..."
cd "$SCRIPT_DIR"
docker compose build app

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Build complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Start containers with:"
echo "  docker compose up -d app"
echo ""
echo "Access at: http://localhost:53851/cadastro"
