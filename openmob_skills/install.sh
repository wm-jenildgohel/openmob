#!/bin/bash
# OpenMob Skill Installer
# Installs OpenMob skill for your AI coding tool

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OPENMOB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "OpenMob Skill Installer"
echo "======================"
echo ""
echo "OpenMob path: $OPENMOB_ROOT"
echo ""

# Detect available AI tools
TOOLS_FOUND=()
command -v claude >/dev/null 2>&1 && TOOLS_FOUND+=("claude-code")
command -v cursor >/dev/null 2>&1 && TOOLS_FOUND+=("cursor")
[ -d "$HOME/.config/Claude" ] && TOOLS_FOUND+=("claude-desktop")
command -v code >/dev/null 2>&1 && TOOLS_FOUND+=("vscode")
command -v codex >/dev/null 2>&1 && TOOLS_FOUND+=("codex")
command -v gemini >/dev/null 2>&1 && TOOLS_FOUND+=("gemini")

if [ ${#TOOLS_FOUND[@]} -eq 0 ]; then
  echo "No AI tools detected. Manual setup required."
  echo ""
  echo "Copy the MCP config for your tool from:"
  echo "  $SCRIPT_DIR/mcp-configs/"
  echo ""
  echo "Or read SKILL.md for HTTP API reference."
  exit 0
fi

echo "Detected AI tools: ${TOOLS_FOUND[*]}"
echo ""

for tool in "${TOOLS_FOUND[@]}"; do
  case "$tool" in
    claude-code)
      echo "[Claude Code]"
      # Add MCP server to Claude Code settings
      SETTINGS_DIR="$HOME/.claude"
      mkdir -p "$SETTINGS_DIR"
      if [ -f "$SETTINGS_DIR/settings.json" ]; then
        echo "  Settings file exists. Add this to mcpServers in $SETTINGS_DIR/settings.json:"
      else
        echo "  Add this to $SETTINGS_DIR/settings.json:"
      fi
      echo ""
      echo "  \"openmob\": {"
      echo "    \"command\": \"node\","
      echo "    \"args\": [\"build/app/index.js\"],"
      echo "    \"cwd\": \"$OPENMOB_ROOT/openmob_mcp\""
      echo "  }"
      echo ""
      # Also install as skill
      if claude skill add "$SCRIPT_DIR" 2>/dev/null; then
        echo "  Skill installed via 'claude skill add'"
      else
        echo "  To install skill: claude skill add $SCRIPT_DIR"
      fi
      echo ""
      ;;

    cursor)
      echo "[Cursor]"
      CURSOR_MCP="$HOME/.cursor/mcp.json"
      echo "  Add to $CURSOR_MCP:"
      echo ""
      sed "s|\${OPENMOB_PATH}|$OPENMOB_ROOT|g" "$SCRIPT_DIR/mcp-configs/cursor.json"
      echo ""
      ;;

    claude-desktop)
      echo "[Claude Desktop]"
      CONFIG_DIR="$HOME/.config/Claude"
      CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"
      echo "  Add to $CONFIG_FILE:"
      echo ""
      sed "s|\${OPENMOB_PATH}|$OPENMOB_ROOT|g" "$SCRIPT_DIR/mcp-configs/claude-desktop.json"
      echo ""
      ;;

    vscode)
      echo "[VS Code]"
      echo "  Add MCP config to .vscode/mcp.json in your project:"
      echo ""
      cat "$SCRIPT_DIR/mcp-configs/vscode.json"
      echo ""
      ;;

    codex|gemini)
      echo "[$tool]"
      echo "  Use the HTTP API directly at http://127.0.0.1:8686"
      echo "  See SKILL.md for full API reference."
      echo ""
      ;;
  esac
done

echo "======================"
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Start the Hub:  cd $OPENMOB_ROOT/openmob_hub && flutter run -d linux"
echo "  2. Connect a device via USB or start an emulator"
echo "  3. Your AI tool can now see and control mobile devices"
