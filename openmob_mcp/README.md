<p align="center">
  <img src="https://raw.githubusercontent.com/wm-jenildgohel/openmob/main/app-logo.png" alt="OpenMob" width="80" height="80">
</p>

<h1 align="center">openmob-mcp</h1>

<p align="center">
  <strong>MCP server for mobile device automation</strong><br>
  Control Android & iOS devices from any AI agent — Claude, Cursor, Windsurf, VS Code
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/openmob-mcp"><img src="https://img.shields.io/npm/v/openmob-mcp?color=green" alt="npm"></a>
  <a href="https://github.com/wm-jenildgohel/openmob"><img src="https://img.shields.io/github/stars/wm-jenildgohel/openmob?style=social" alt="GitHub"></a>
  <a href="https://github.com/wm-jenildgohel/openmob/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License"></a>
</p>

---

## Quick Start

### For Claude Desktop / Cursor / Windsurf

Add to your MCP config:

```json
{
  "mcpServers": {
    "openmob": {
      "command": "npx",
      "args": ["-y", "openmob-mcp"]
    }
  }
}
```

### For VS Code

Add to `.vscode/mcp.json`:

```json
{
  "servers": {
    "openmob": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "openmob-mcp"]
    }
  }
}
```

### Prerequisites

1. **OpenMob Hub** must be running (download from [releases](https://github.com/wm-jenildgohel/openmob/releases))
2. **Android device** connected via USB, or emulator running

## 34 Tools Available

### Device Discovery
| Tool | What it does |
|------|-------------|
| `list_devices` | See all connected devices |
| `get_screenshot` | Capture the device screen |
| `get_ui_tree` | Read all UI elements with indices |
| `find_element` | Smart search by text, class, resource ID |
| `get_screen_size` | Get screen dimensions |
| `get_orientation` | Check portrait/landscape |

### Touch & Input
| Tool | What it does |
|------|-------------|
| `tap` | Tap by element index or coordinates |
| `double_tap` | Double-tap gesture |
| `long_press` | Long press with duration |
| `type_text` | Type into focused field (+ optional submit) |
| `swipe` | Scroll by direction or coordinates |
| `press_button` | Press Home/Back/Volume/Power |
| `go_home` | Go to home screen |
| `open_url` | Open URL or deep link |

### App Management
| Tool | What it does |
|------|-------------|
| `launch_app` | Open app by package name |
| `terminate_app` | Kill running app |
| `install_app` | Install APK from file |
| `uninstall_app` | Remove app |
| `list_apps` | List installed apps |
| `clear_app_data` | Reset app to fresh state |
| `grant_permissions` | Auto-grant all permissions |

### Device Settings
| Tool | What it does |
|------|-------------|
| `get_current_activity` | See current app/screen |
| `get_device_logs` | Read logcat for debugging |
| `get_notifications` | Read notification bar |
| `set_rotation` | Rotate screen |
| `toggle_wifi` | WiFi on/off |
| `toggle_airplane_mode` | Airplane mode on/off |
| `save_screenshot` | Save screenshot to file |

### Recording & Testing
| Tool | What it does |
|------|-------------|
| `start_recording` | Record device screen |
| `stop_recording` | Stop and save recording |
| `get_recording` | Get recording details |
| `list_recordings` | List all recordings |
| `run_test` | Run multi-step test scenario |
| `wait_for_element` | Wait for UI element to appear |

## How It Works

```
AI Agent (Claude / Cursor / Codex)
    |
    v
openmob-mcp (this package, stdio)
    |
    v
OpenMob Hub (localhost:8686)
    |
    v
ADB / xcrun simctl
    |
    v
Your Device
```

The MCP server is a thin proxy — all device operations go through the OpenMob Hub HTTP API. The Hub handles ADB commands, device state, and cross-platform support.

## All tools also available with `mobile_` prefix

For compatibility with mobile-mcp convention, every tool is also registered with a `mobile_` prefix:
`mobile_tap`, `mobile_swipe`, `mobile_screenshot`, etc.

## Free & Open Source

OpenMob is a free, self-hosted alternative to MobAI. No quotas, no limits, no cloud dependency.

- [GitHub](https://github.com/wm-jenildgohel/openmob)
- [Download Hub](https://github.com/wm-jenildgohel/openmob/releases)
- [MIT License](https://github.com/wm-jenildgohel/openmob/blob/main/LICENSE)
