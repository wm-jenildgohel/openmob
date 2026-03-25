#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="${PROJECT_DIR}/dist"

echo "[build-sea] Building OpenMob MCP as standalone binary..."

cd "$PROJECT_DIR"

# Step 1: Install deps + compile TypeScript
echo "[build-sea] Installing dependencies..."
npm install --production=false
echo "[build-sea] Compiling TypeScript..."
npm run build

# Step 2: Bundle into single JS file using esbuild
echo "[build-sea] Bundling into single file..."
npx esbuild build/app/index.js \
  --bundle \
  --platform=node \
  --target=node20 \
  --format=cjs \
  --outfile=dist/openmob-mcp-bundle.cjs \
  --external:@modelcontextprotocol/sdk

# Actually, for SEA we need all deps inlined. Let's bundle everything.
npx esbuild build/app/index.js \
  --bundle \
  --platform=node \
  --target=node20 \
  --format=cjs \
  --outfile=dist/openmob-mcp-bundle.cjs

# Step 3: Generate SEA blob
echo "[build-sea] Generating SEA blob..."
node --experimental-sea-config sea-config.json 2>/dev/null || {
  # SEA config expects main to be a single file — update and retry
  cp sea-config.json sea-config-bundle.json
  sed -i 's|build/app/index.js|dist/openmob-mcp-bundle.cjs|' sea-config-bundle.json
  node --experimental-sea-config sea-config-bundle.json
}

# Step 4: Copy node binary and inject blob
echo "[build-sea] Creating standalone executable..."
mkdir -p "$OUTPUT_DIR"
NODE_BIN=$(which node)
cp "$NODE_BIN" "$OUTPUT_DIR/openmob-mcp"

# Inject the SEA blob
npx postject "$OUTPUT_DIR/openmob-mcp" NODE_SEA_BLOB sea-prep.blob \
  --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2 2>/dev/null || {
  # postject might not be installed — install it
  npm install -g postject 2>/dev/null || npx -y postject "$OUTPUT_DIR/openmob-mcp" NODE_SEA_BLOB sea-prep.blob \
    --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2
}

chmod +x "$OUTPUT_DIR/openmob-mcp"

# Clean up
rm -f sea-prep.blob sea-config-bundle.json

echo "[build-sea] Done: $OUTPUT_DIR/openmob-mcp"
echo "[build-sea] Size: $(du -h "$OUTPUT_DIR/openmob-mcp" | cut -f1)"
