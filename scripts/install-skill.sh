#!/bin/bash
# OpenMob Skill Installer — one command to set up everything
# Usage: curl -fsSL https://raw.githubusercontent.com/wm-jenildgohel/openmob/main/scripts/install-skill.sh | bash
set -e

REPO="wm-jenildgohel/openmob"
BRANCH="main"
BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║     OpenMob — Skill Installer        ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

# 1. Install Claude Code skill
SKILL_DIR="$HOME/.claude/skills/openmob"
mkdir -p "$SKILL_DIR"
curl -fsSL "$BASE/.claude/skills/openmob/SKILL.md" -o "$SKILL_DIR/SKILL.md"
echo -e "${GREEN}[+]${NC} Claude Code skill installed to $SKILL_DIR"

# 2. Add MCP server via claude CLI (if available)
if command -v claude &>/dev/null; then
    claude mcp add openmob -- npx -y openmob-mcp 2>/dev/null && \
        echo -e "${GREEN}[+]${NC} MCP server added to Claude Code" || \
        echo -e "${YELLOW}[!]${NC} Could not add MCP via CLI — add manually"
fi

# 3. Configure Claude Desktop (if installed)
configure_mcp() {
    local config_path="$1"
    local tool_name="$2"

    if [ ! -f "$config_path" ] && [ ! -d "$(dirname "$config_path")" ]; then
        return
    fi

    mkdir -p "$(dirname "$config_path")"

    if [ -f "$config_path" ] && grep -q "openmob" "$config_path" 2>/dev/null; then
        echo -e "${GREEN}[+]${NC} $tool_name already configured"
        return
    fi

    # Create or update config
    if [ -f "$config_path" ]; then
        # Add openmob to existing config using python (available everywhere)
        python3 -c "
import json, sys
try:
    with open('$config_path') as f: config = json.load(f)
except: config = {}
servers = config.setdefault('mcpServers', {})
servers['openmob'] = {'command': 'npx', 'args': ['-y', 'openmob-mcp']}
with open('$config_path', 'w') as f: json.dump(config, f, indent=2)
print('OK')
" 2>/dev/null && echo -e "${GREEN}[+]${NC} $tool_name configured" || \
        echo -e "${YELLOW}[!]${NC} Could not auto-configure $tool_name — add manually"
    else
        # Create new config
        cat > "$config_path" << 'MCPJSON'
{
  "mcpServers": {
    "openmob": {
      "command": "npx",
      "args": ["-y", "openmob-mcp"]
    }
  }
}
MCPJSON
        echo -e "${GREEN}[+]${NC} $tool_name configured"
    fi
}

# Detect OS and configure AI tools
case "$(uname -s)" in
    Darwin)
        configure_mcp "$HOME/Library/Application Support/Claude/claude_desktop_config.json" "Claude Desktop"
        configure_mcp "$HOME/.cursor/mcp.json" "Cursor"
        ;;
    Linux)
        configure_mcp "$HOME/.config/Claude/claude_desktop_config.json" "Claude Desktop"
        configure_mcp "$HOME/.cursor/mcp.json" "Cursor"
        ;;
esac

# 4. Install Windsurf rules
WINDSURF_DIR="$HOME/.windsurf/rules"
if [ -d "$HOME/.windsurf" ] || [ -d "$(dirname "$WINDSURF_DIR")" ]; then
    mkdir -p "$WINDSURF_DIR"
    curl -fsSL "$BASE/.claude/skills/openmob/SKILL.md" -o "$WINDSURF_DIR/openmob.md"
    echo -e "${GREEN}[+]${NC} Windsurf rules installed"
fi

# 5. Install Codex AGENTS.md
CODEX_DIR="$HOME/.codex"
if [ -d "$CODEX_DIR" ] || command -v codex &>/dev/null; then
    mkdir -p "$CODEX_DIR"
    curl -fsSL "$BASE/.claude/skills/openmob/SKILL.md" -o "$CODEX_DIR/AGENTS.md"
    echo -e "${GREEN}[+]${NC} Codex CLI AGENTS.md installed"
fi

# 6. Install Gemini instructions
GEMINI_DIR="$HOME/.gemini"
if [ -d "$GEMINI_DIR" ] || command -v gemini &>/dev/null; then
    mkdir -p "$GEMINI_DIR"
    curl -fsSL "$BASE/.claude/skills/openmob/SKILL.md" -o "$GEMINI_DIR/GEMINI.md"
    echo -e "${GREEN}[+]${NC} Gemini CLI instructions installed"
fi

echo ""
echo -e "${GREEN}Done!${NC} OpenMob skill installed for all detected AI tools."
echo ""
echo "Next steps:"
echo "  1. Download OpenMob Hub: https://github.com/${REPO}/releases"
echo "  2. Connect an Android device via USB"
echo "  3. Start the Hub — it handles everything else"
echo ""
echo "Or use MCP directly (no Hub needed for basic commands):"
echo "  npx openmob-mcp"
echo ""
