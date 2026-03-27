#!/bin/bash
# Build OpenMob Linux AppImage
# Usage: ./build-appimage.sh <version> <hub-dir> <mcp-binary> <bridge-binary>

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

# Create AppDir — Flutter expects data/ and lib/ NEXT TO the executable
# So we put everything flat under usr/bin/ to preserve Flutter's bundle structure
mkdir -p "$APPDIR/usr/bin"

# Copy the ENTIRE Flutter bundle as-is (preserves relative paths)
cp -r "$HUB_DIR"/* "$APPDIR/usr/bin/"

# Copy companion binaries into the same directory
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

# Copy icon
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [ -f "$REPO_ROOT/app-logo.png" ]; then
    cp "$REPO_ROOT/app-logo.png" "$APPDIR/openmob.png"
elif [ -f "$REPO_ROOT/openmob_hub/assets/icon.png" ]; then
    cp "$REPO_ROOT/openmob_hub/assets/icon.png" "$APPDIR/openmob.png"
else
    echo "Warning: No icon found, using placeholder"
    printf '\x89PNG\r\n\x1a\n' > "$APPDIR/openmob.png"
fi

# Create AppRun launcher — cd to usr/bin so Flutter finds data/ and lib/ next to it
cat > "$APPDIR/AppRun" << 'APPRUN'
#!/bin/bash
HERE="$(dirname "$(readlink -f "${0}")")"
BUNDLE="${HERE}/usr/bin"

# Flutter needs data/ and lib/ relative to the executable
export LD_LIBRARY_PATH="${BUNDLE}/lib:${LD_LIBRARY_PATH:-}"
export PATH="${BUNDLE}:${PATH}"

cd "${BUNDLE}"
exec "./openmob_hub" "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

# Download appimagetool if not present
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    echo "Downloading appimagetool..."
    wget -q "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x appimagetool-x86_64.AppImage
fi

# Build AppImage
echo "Packaging AppImage..."
ARCH=x86_64 ./appimagetool-x86_64.AppImage --appimage-extract-and-run "$APPDIR" "$OUTPUT"

echo ""
echo "Built: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
echo "Run with: chmod +x $OUTPUT && ./$OUTPUT"
