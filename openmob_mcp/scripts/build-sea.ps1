$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$OutputDir = Join-Path $ProjectDir "dist"

Write-Host "[build-sea] Building OpenMob MCP as standalone binary..." -ForegroundColor Cyan

Set-Location $ProjectDir

# Step 1: Install deps + compile TypeScript
Write-Host "[build-sea] Installing dependencies..."
npm install --production=false
Write-Host "[build-sea] Compiling TypeScript..."
npm run build

# Step 2: Bundle into single JS file
Write-Host "[build-sea] Bundling into single file..."
npx esbuild build/app/index.js `
  --bundle `
  --platform=node `
  --target=node20 `
  --format=cjs `
  --outfile=dist/openmob-mcp-bundle.cjs

# Step 3: Generate SEA blob using bundled file
$seaConfig = @{
  main = "dist/openmob-mcp-bundle.cjs"
  output = "sea-prep.blob"
  disableExperimentalSEAWarning = $true
  useSnapshot = $false
  useCodeCache = $true
} | ConvertTo-Json
$seaConfig | Out-File -Encoding utf8 "sea-config-bundle.json"

Write-Host "[build-sea] Generating SEA blob..."
node --experimental-sea-config sea-config-bundle.json

# Step 4: Copy node binary and inject blob
Write-Host "[build-sea] Creating standalone executable..."
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$nodeBin = (Get-Command node).Source
Copy-Item $nodeBin (Join-Path $OutputDir "openmob-mcp.exe")

# Remove signature (required on Windows for SEA injection)
try {
  signtool remove /s (Join-Path $OutputDir "openmob-mcp.exe") 2>$null
} catch {
  Write-Host "[build-sea] signtool not found — skipping signature removal (may work anyway)"
}

# Inject blob
npx -y postject (Join-Path $OutputDir "openmob-mcp.exe") NODE_SEA_BLOB sea-prep.blob `
  --sentinel-fuse NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2

# Clean up
Remove-Item -ErrorAction SilentlyContinue sea-prep.blob, sea-config-bundle.json

$size = (Get-Item (Join-Path $OutputDir "openmob-mcp.exe")).Length / 1MB
Write-Host "[build-sea] Done: $OutputDir\openmob-mcp.exe" -ForegroundColor Green
Write-Host "[build-sea] Size: $([math]::Round($size, 1)) MB"
