#!/bin/bash
# Build OpenMob Linux AppImage
# Usage: ./build-appimage.sh <version> <hub-dir> <mcp-binary> <bridge-binary>
# Example: ./build-appimage.sh 0.0.9 ../artifacts/hub-linux ../artifacts/mcp-linux/openmob-mcp ../artifacts/bridge-linux/aibridge

set -euo pipefail

VERSION="${1:?Usage: $0 <version> <hub-dir> <mcp-binary> <bridge-binary>}"
HUB_DIR="${2:?Missing hub build directory}"
MCP_BIN="${3:?Missing MCP binary path}"
BRIDGE_BIN="${4:?Missing AiBridge binary path}"

APPDIR="OpenMob.AppDir"
OUTPUT="OpenMob-${VERSION}-x86_64.AppImage"

echo "Building OpenMob AppImage v${VERSION}..."

# Clean previous build
rm -rf "$APPDIR" "$OUTPUT"

# Create AppDir structure
mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/share/openmob_hub"

# Copy Flutter Hub
cp "$HUB_DIR/openmob_hub" "$APPDIR/usr/bin/"
cp -r "$HUB_DIR/lib/"* "$APPDIR/usr/lib/" 2>/dev/null || true
cp -r "$HUB_DIR/data" "$APPDIR/usr/share/openmob_hub/" 2>/dev/null || true

# Copy companion binaries
cp "$MCP_BIN" "$APPDIR/usr/bin/openmob-mcp"
cp "$BRIDGE_BIN" "$APPDIR/usr/bin/aibridge"
chmod +x "$APPDIR/usr/bin/"*

# Create .desktop file
cat > "$APPDIR/openmob.desktop" << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=OpenMob
GenericName=Mobile Device Automation
Comment=AI-powered mobile device control and testing
Exec=openmob_hub
Icon=openmob
Categories=Development;IDE;
Keywords=mobile;android;ios;testing;automation;ai;mcp;
StartupWMClass=openmob_hub
DESKTOP

# Copy icon (use app-logo.png from repo root, convert to 256x256 if needed)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -f "$REPO_ROOT/app-logo.png" ]; then
    cp "$REPO_ROOT/app-logo.png" "$APPDIR/openmob.png"
elif [ -f "$REPO_ROOT/openmob_hub/assets/icon.png" ]; then
    cp "$REPO_ROOT/openmob_hub/assets/icon.png" "$APPDIR/openmob.png"
else
    # Create a minimal 1x1 PNG as fallback (appimagetool requires an icon)
    echo "Warning: No icon found, using placeholder"
    printf '\x89PNG\r\n\x1a\n' > "$APPDIR/openmob.png"
fi

# Create AppRun launcher
cat > "$APPDIR/AppRun" << 'APPRUN'
#!/bin/bash
# OpenMob AppImage launcher
HERE="$(dirname "$(readlink -f "${0}")")"

# Set library path for Flutter shared libs
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH:-}"

# Add companion binaries to PATH (MCP + AiBridge)
export PATH="${HERE}/usr/bin:${PATH}"

# Flutter needs the data directory
export FLUTTER_ASSET_DIR="${HERE}/usr/share/openmob_hub/data"

# Launch Hub
exec "${HERE}/usr/bin/openmob_hub" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# Download appimagetool if not present
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    echo "Downloading appimagetool..."
    wget -q "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x appimagetool-x86_64.AppImage
fi

# Build AppImage
# Use --appimage-extract-and-run for environments without FUSE (CI, containers)
echo "Packaging AppImage..."
ARCH=x86_64 ./appimagetool-x86_64.AppImage --appimage-extract-and-run "$APPDIR" "$OUTPUT"

echo ""
echo "Built: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
echo "Run with: chmod +x $OUTPUT && ./$OUTPUT"
