#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Normalize arch
case "$ARCH" in
  x86_64) ARCH="x64" ;;
  aarch64|arm64) ARCH="arm64" ;;
esac

BUNDLE_NAME="openmob-${PLATFORM}-${ARCH}"
BUNDLE_DIR="$DIST_DIR/$BUNDLE_NAME"

echo "========================================="
echo " OpenMob Full Build"
echo " Platform: $PLATFORM-$ARCH"
echo " Output:   $BUNDLE_DIR"
echo "========================================="

# Step 1: Build AiBridge (Rust)
echo ""
echo "[1/4] Building AiBridge (Rust)..."
cd "$ROOT_DIR/openmob_bridge"
source "$HOME/.cargo/env" 2>/dev/null || true
cargo build --release
echo "  -> $(du -h target/release/aibridge | cut -f1)"

# Step 2: Build MCP Server (Node.js SEA)
echo ""
echo "[2/4] Building MCP Server (Node.js SEA)..."
cd "$ROOT_DIR/openmob_mcp"
bash scripts/build-sea.sh

# Step 3: Build Hub (Flutter Desktop)
echo ""
echo "[3/4] Building Hub (Flutter Desktop)..."
cd "$ROOT_DIR/openmob_hub"
flutter pub get
flutter build linux --release

# Step 4: Package everything
echo ""
echo "[4/4] Packaging..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Copy Flutter build output
FLUTTER_BUNDLE="$ROOT_DIR/openmob_hub/build/linux/$ARCH/release/bundle"
cp -r "$FLUTTER_BUNDLE"/* "$BUNDLE_DIR/"

# Copy MCP SEA binary next to hub exe
cp "$ROOT_DIR/openmob_mcp/dist/openmob-mcp" "$BUNDLE_DIR/openmob-mcp"
chmod +x "$BUNDLE_DIR/openmob-mcp"

# Copy AiBridge binary next to hub exe
cp "$ROOT_DIR/openmob_bridge/target/release/aibridge" "$BUNDLE_DIR/aibridge"
chmod +x "$BUNDLE_DIR/aibridge"

# Copy skills
if [ -d "$ROOT_DIR/openmob_skills" ]; then
  cp -r "$ROOT_DIR/openmob_skills" "$BUNDLE_DIR/openmob_skills"
fi

# Create launcher script
cat > "$BUNDLE_DIR/openmob" << 'LAUNCHER'
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
export LD_LIBRARY_PATH="$DIR/lib:$LD_LIBRARY_PATH"
exec "$DIR/openmob_hub" "$@"
LAUNCHER
chmod +x "$BUNDLE_DIR/openmob"

# Create ZIP
echo ""
echo "Creating archive..."
cd "$DIST_DIR"
tar -czf "${BUNDLE_NAME}.tar.gz" "$BUNDLE_NAME"

echo ""
echo "========================================="
echo " Build Complete!"
echo ""
echo " Bundle: $BUNDLE_DIR"
echo " Archive: $DIST_DIR/${BUNDLE_NAME}.tar.gz"
echo ""
echo " Contents:"
ls -lh "$BUNDLE_DIR/openmob_hub" "$BUNDLE_DIR/openmob-mcp" "$BUNDLE_DIR/aibridge" 2>/dev/null
echo ""
echo " Total: $(du -sh "$BUNDLE_DIR" | cut -f1)"
echo "========================================="
