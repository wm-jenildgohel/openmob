# OpenMob Skill Installer for Windows
# Usage: irm https://raw.githubusercontent.com/wm-jenildgohel/openmob/main/scripts/install-skill.ps1 | iex
$ErrorActionPreference = "Stop"

$repo = "wm-jenildgohel/openmob"
$branch = "main"
$base = "https://raw.githubusercontent.com/$repo/$branch"

Write-Host ""
Write-Host "  +======================================+" -ForegroundColor Cyan
Write-Host "  |     OpenMob - Skill Installer        |" -ForegroundColor Cyan
Write-Host "  +======================================+" -ForegroundColor Cyan
Write-Host ""

# 1. Install Claude Code skill
$skillDir = "$env:USERPROFILE\.claude\skills\openmob"
New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
Invoke-WebRequest -Uri "$base/.claude/skills/openmob/SKILL.md" -OutFile "$skillDir\SKILL.md"
Write-Host "[+] Claude Code skill installed" -ForegroundColor Green

# 2. Add MCP via claude CLI
try {
    $claudePath = Get-Command claude -ErrorAction SilentlyContinue
    if ($claudePath) {
        & claude mcp add openmob -- npx -y openmob-mcp 2>$null
        Write-Host "[+] MCP server added to Claude Code" -ForegroundColor Green
    }
} catch {
    Write-Host "[!] Claude Code CLI not found - skip" -ForegroundColor Yellow
}

# 3. Configure Claude Desktop
function Set-McpConfig {
    param($ConfigPath, $ToolName)

    $dir = Split-Path $ConfigPath -Parent
    if (-not (Test-Path $dir)) { return }

    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $openmobEntry = @{
        command = "npx"
        args = @("-y", "openmob-mcp")
    }

    if (Test-Path $ConfigPath) {
        try {
            $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        } catch {
            $config = @{}
        }
    } else {
        $config = @{}
    }

    if (-not $config.mcpServers) {
        $config | Add-Member -NotePropertyName mcpServers -NotePropertyValue @{} -Force
    }
    $config.mcpServers | Add-Member -NotePropertyName openmob -NotePropertyValue $openmobEntry -Force

    $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
    Write-Host "[+] $ToolName configured" -ForegroundColor Green
}

# Claude Desktop
$claudeDesktopConfig = "$env:APPDATA\Claude\claude_desktop_config.json"
if (Test-Path (Split-Path $claudeDesktopConfig -Parent)) {
    Set-McpConfig $claudeDesktopConfig "Claude Desktop"
}

# Cursor
$cursorConfig = "$env:USERPROFILE\.cursor\mcp.json"
if (Test-Path "$env:USERPROFILE\.cursor") {
    Set-McpConfig $cursorConfig "Cursor"
}

# 4. Windsurf
$windsurfDir = "$env:USERPROFILE\.windsurf\rules"
if (Test-Path "$env:USERPROFILE\.windsurf") {
    New-Item -ItemType Directory -Force -Path $windsurfDir | Out-Null
    Invoke-WebRequest -Uri "$base/.claude/skills/openmob/SKILL.md" -OutFile "$windsurfDir\openmob.md"
    Write-Host "[+] Windsurf rules installed" -ForegroundColor Green
}

# 5. Codex CLI
$codexDir = "$env:USERPROFILE\.codex"
if ((Test-Path $codexDir) -or (Get-Command codex -ErrorAction SilentlyContinue)) {
    New-Item -ItemType Directory -Force -Path $codexDir | Out-Null
    Invoke-WebRequest -Uri "$base/.claude/skills/openmob/SKILL.md" -OutFile "$codexDir\AGENTS.md"
    Write-Host "[+] Codex CLI AGENTS.md installed" -ForegroundColor Green
}

# 6. Gemini CLI
$geminiDir = "$env:USERPROFILE\.gemini"
if ((Test-Path $geminiDir) -or (Get-Command gemini -ErrorAction SilentlyContinue)) {
    New-Item -ItemType Directory -Force -Path $geminiDir | Out-Null
    Invoke-WebRequest -Uri "$base/.claude/skills/openmob/SKILL.md" -OutFile "$geminiDir\GEMINI.md"
    Write-Host "[+] Gemini CLI instructions installed" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done! OpenMob skill installed for all detected AI tools." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Download OpenMob Hub: https://github.com/$repo/releases"
Write-Host "  2. Connect an Android device via USB"
Write-Host "  3. Start the Hub - it handles everything else"
Write-Host ""
