# OpenMob

**Free, self-hosted alternative to [MobAI](https://mobai.run) — give AI coding agents the ability to see and control mobile devices.**

No quotas. No daily limits. No cloud dependency. Fully open source.

---

## The Problem

AI coding agents (Claude Code, Cursor, Codex, Gemini) can write mobile app code but **can't see or interact with the actual device**. They're coding blind — they can't verify if a button works, if a layout looks right, or if a login flow actually succeeds.

**MobAI** solves this but:
- Free tier: 100 points/day, 1 device only
- Plus ($4.99/mo): still 1 device, 1 machine
- Pro ($9.99/mo): unlimited devices but requires internet for license validation
- Closed source desktop app

## The Solution

**OpenMob** gives your AI agents eyes and hands on mobile devices — completely free, self-hosted, and open source.

```
AI Agent (Claude Code / Cursor / Codex / Gemini)
         |
    ┌────┼────┐
    |    |    |
   MCP  HTTP  AiBridge
    |    |    |
    └────┼────┘
         |
   OpenMob Hub (Desktop App)
         |
    ┌────┼────┐
    |         |
  ADB      xcrun/idb
    |         |
 Android    iOS
 Device   Simulator
```

### What AI Agents Can Do With OpenMob

| Capability | How |
|-----------|-----|
| **See the screen** | Screenshot capture as base64 PNG |
| **Read UI elements** | Accessibility tree with element indices |
| **Tap buttons** | By element index or x,y coordinates |
| **Type text** | Into any focused input field |
| **Swipe/scroll** | Up, down, left, right with configurable speed |
| **Press keys** | Home, Back, Enter, Volume, Power |
| **Launch apps** | By package name or bundle ID |
| **Kill apps** | Force stop any running app |
| **Open URLs** | Deep links and web URLs |
| **Run tests** | Structured test scripts with pass/fail results |

## Components

OpenMob has 3 components that work together:

### 1. Hub — Flutter Desktop App (`openmob_hub/`)

The brain. Manages devices, runs the HTTP API, provides the desktop UI.

- **HTTP API** on `localhost:8686` — 16+ REST endpoints for device control
- **Device management** — auto-discovers Android (USB/WiFi/emulator) and iOS Simulators
- **Desktop UI** — device list, live screen preview, process controls, log viewer, test runner
- **Tech**: Flutter 3.41, Dart, shelf HTTP server, rxdart for state management

### 2. MCP Server — TypeScript (`openmob_mcp/`)

The bridge to AI tools. Exposes device tools via the [Model Context Protocol](https://modelcontextprotocol.io/).

- **12 MCP tools** — list_devices, get_screenshot, get_ui_tree, tap, type_text, swipe, launch_app, terminate_app, press_button, go_home, open_url, run_test
- **Works with** — Cursor, Claude Desktop, Windsurf, VS Code, any MCP client
- **Stateless** — all calls proxy to the Hub HTTP API
- **Auto-detects Hub** — probes ports 8686-8690 automatically
- **Tech**: TypeScript, @modelcontextprotocol/sdk, SOLID/SRP architecture

### 3. AiBridge — Rust CLI (`openmob_bridge/`)

Optional. Wraps terminal AI agents with context injection.

- **PTY wrapper** — wraps Claude Code, Codex, Gemini CLI in a pseudo-terminal
- **HTTP injection API** on `localhost:9999` — POST text into the agent when idle
- **Idle detection** — regex-based, built-in patterns for 3 major agents
- **Tech**: Rust, portable-pty, axum, tokio, clap

## Quick Start

### Option 1: Pre-built Binaries

Download from [Releases](https://github.com/wm-jenildgohel/openmob/releases):

**Linux:**
```bash
tar xzf openmob-linux-x64.tar.gz
cd openmob-linux-x64
./openmob
```

**Windows:**
```
Extract openmob-windows-x64.zip
Double-click openmob.bat
```

### Option 2: Build from Source

**Prerequisites:**
- **Flutter 3.29.3** (exact version required — see below)
- Node.js 18+ (`node --version`)
- Rust 1.70+ (`rustc --version`)
- ADB (`adb devices`)

> **Flutter Version:** OpenMob Hub requires **Flutter 3.29.3**. Using a different version may cause build errors. We recommend using [FVM (Flutter Version Management)](https://fvm.app) to manage Flutter versions without affecting your global install.

**With FVM (recommended):**
```bash
# Install FVM if you don't have it
dart pub global activate fvm

git clone https://github.com/wm-jenildgohel/openmob.git
cd openmob

# Install correct Flutter version (reads .fvmrc automatically)
cd openmob_hub && fvm install && fvm use

# Build Hub
fvm flutter pub get && fvm flutter build linux && cd ..

# Build MCP Server
cd openmob_mcp && npm install && npm run build && cd ..

# Build AiBridge
cd openmob_bridge && cargo build --release && cd ..

# Run
cd openmob_hub && fvm flutter run -d linux
```

**Without FVM (if you already have Flutter 3.29.x):**
```bash
git clone https://github.com/wm-jenildgohel/openmob.git
cd openmob

# Build Hub
cd openmob_hub && flutter pub get && flutter build linux && cd ..

# Build MCP Server
cd openmob_mcp && npm install && npm run build && cd ..

# Build AiBridge
cd openmob_bridge && cargo build --release && cd ..

# Run
cd openmob_hub && flutter run -d linux
```

### Option 3: MCP Only (No Desktop UI)

If you just want AI agents to control devices:

```bash
cd openmob_mcp && npm install && npm run build

# Add to your AI tool's MCP config:
# { "command": "node", "args": ["build/app/index.js"], "cwd": "/path/to/openmob_mcp" }
```

## Setup for AI Tools

### Cursor / Claude Desktop / Windsurf

Add to MCP settings:
```json
{
  "mcpServers": {
    "openmob": {
      "command": "node",
      "args": ["build/app/index.js"],
      "cwd": "/path/to/openmob_mcp"
    }
  }
}
```

### Claude Code

```bash
# Add MCP server
claude mcp add openmob node build/app/index.js --cwd /path/to/openmob_mcp
```

### VS Code (Copilot)

Add to `.vscode/mcp.json`:
```json
{
  "servers": {
    "openmob": {
      "type": "stdio",
      "command": "node",
      "args": ["build/app/index.js"],
      "cwd": "${workspaceFolder}/../openmob_mcp"
    }
  }
}
```

### Any HTTP-capable Agent

Point to the Hub API directly:
```bash
# List devices
curl http://localhost:8686/api/v1/devices/

# Screenshot
curl http://localhost:8686/api/v1/devices/{id}/screenshot

# Tap element
curl -X POST http://localhost:8686/api/v1/devices/{id}/tap -d '{"index": 5}'
```

Full API reference in [`openmob_skills/SKILL.md`](openmob_skills/SKILL.md).

## How It Works

### The See-Think-Act Loop

```
1. AI asks: "What's on screen?"
   → MCP: get_screenshot + get_ui_tree
   → Returns: PNG image + 58 UI elements with indices

2. AI decides: "I need to tap the Login button at index 15"
   → MCP: tap(device_id, index=15)
   → Hub: resolves index to coordinates, runs `adb shell input tap`

3. AI verifies: "Did the login screen appear?"
   → MCP: get_ui_tree(visible=true)
   → Returns: new elements including "Enter Password" at index 12

4. AI continues: types email, password, taps Submit
   → Full login flow automated without human intervention
```

### Real Example: Testing a Login Flow

This was tested live on a real Android device:

| Step | AI Action | Result |
|------|-----------|--------|
| 1 | `launch_app("com.example.myapp")` | App opened |
| 2 | `get_ui_tree(visible=true)` → found "Profile" at index 25 | Read screen |
| 3 | `tap(index=25)` | "Account required" dialog appeared |
| 4 | `tap(index=15)` → "Sign In" | Login screen opened |
| 5 | `tap(x=720, y=855)` → focus email field | Keyboard appeared |
| 6 | `type_text("test@example.com")` | Email entered |
| 7 | `tap(index=16)` → "Using Password" | Password screen appeared |
| 8 | `tap(x=720, y=908)` + `type_text("Test@1234")` | Password entered |
| 9 | `tap(index=18)` → "Sign In" | "User not found" error toast caught |

The AI successfully automated the entire login flow and verified the error handling.

## API Reference

### Devices
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/devices/` | List all connected devices |
| GET | `/api/v1/devices/{id}/screenshot` | Capture screenshot (base64 PNG) |
| GET | `/api/v1/devices/{id}/ui-tree` | Get UI accessibility tree |
| GET | `/api/v1/devices/{id}/ui-tree?visible=true` | Get visible elements only |

### Actions
| Method | Endpoint | Body | Description |
|--------|----------|------|-------------|
| POST | `/api/v1/devices/{id}/tap` | `{"index": N}` or `{"x": 720, "y": 1480}` | Tap element or coordinates |
| POST | `/api/v1/devices/{id}/type` | `{"text": "hello"}` | Type into focused field |
| POST | `/api/v1/devices/{id}/swipe` | `{"x1":720,"y1":1800,"x2":720,"y2":800}` | Swipe gesture |
| POST | `/api/v1/devices/{id}/keyevent` | `{"keyCode": 3}` | Press key (Home=3, Back=4) |
| POST | `/api/v1/devices/{id}/launch` | `{"package": "com.app"}` | Launch app |
| POST | `/api/v1/devices/{id}/terminate` | `{"package": "com.app"}` | Kill app |
| POST | `/api/v1/devices/{id}/open-url` | `{"url": "https://..."}` | Open URL on device |

### Health
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Hub health check |

## OpenMob vs MobAI

| Feature | MobAI Free | MobAI Pro ($9.99/mo) | OpenMob |
|---------|-----------|---------------------|---------|
| Devices | 1 | Unlimited | **Unlimited** |
| Daily quota | 100 points | Unlimited | **Unlimited** |
| Machines | 1 | 3 | **Unlimited** |
| Offline mode | No | 7 days | **Always offline** |
| Source code | Closed | Closed | **MIT licensed** |
| Telemetry | Yes | Yes | **None** |
| Cloud dependency | Required | Required | **None** |
| Price | Free (limited) | $99/year | **Free forever** |

## Project Structure

```
openmob/
├── openmob_hub/          # Flutter Desktop Hub (Dart)
│   ├── lib/
│   │   ├── core/         # Constants, colors
│   │   ├── models/       # Device, UiNode, ActionResult, TestScript
│   │   ├── server/       # shelf HTTP API + routes
│   │   ├── services/     # ADB, DeviceManager, Screenshot, UiTree, Action, Process, Log
│   │   └── ui/           # Screens + Widgets (rxdart, zero setState)
│   └── pubspec.yaml
├── openmob_mcp/          # MCP Server (TypeScript)
│   ├── src/
│   │   ├── app/          # Bootstrap, server factory, tool registration
│   │   ├── mcp/
│   │   │   ├── common/   # Hub client, response helpers, schemas
│   │   │   └── tools/    # device/, action/, testing/ (SOLID/SRP)
│   │   └── types/        # TypeScript interfaces
│   └── package.json
├── openmob_bridge/       # AiBridge CLI (Rust)
│   ├── src/
│   │   ├── main.rs       # CLI entry, signal handling, tool detection
│   │   ├── bridge.rs     # Orchestrator (4 tokio tasks)
│   │   ├── pty_handler.rs # PTY spawn, read, write, inject
│   │   ├── busy_detector.rs # Idle detection state machine
│   │   ├── queue.rs      # Injection queue (FIFO + priority)
│   │   ├── server.rs     # Axum HTTP server
│   │   ├── handlers.rs   # /health, /status, /inject, /queue
│   │   ├── patterns.rs   # Agent idle patterns
│   │   └── ansi.rs       # ANSI escape stripping
│   └── Cargo.toml
├── openmob_skills/       # Skill package for AI tools
│   ├── SKILL.md          # Full API reference
│   ├── install.sh        # Auto-detect + install for all AI tools
│   ├── agents/           # OpenAI Agents SDK definitions
│   └── mcp-configs/      # Ready configs for Cursor, Claude, VS Code
├── dist/                 # Pre-built binaries
│   ├── openmob-linux-x64/
│   └── openmob-windows-x64/
└── LICENSE               # MIT
```

## Supported Platforms

### Device Automation
| Platform | Connection | Screenshot | UI Tree | Tap/Swipe/Type | Notes |
|----------|-----------|------------|---------|----------------|-------|
| Android (physical) | USB, WiFi ADB | Yes | Yes | Yes | Full support |
| Android (emulator) | ADB auto-detect | Yes | Yes | Yes | Full support |
| iOS (simulator) | xcrun simctl | Yes | Yes (idb) | Yes (idb) | macOS only, requires idb |

### Hub Desktop App
| OS | Status |
|----|--------|
| Linux (x64) | Pre-built binary available |
| Windows (x64) | Build from source (Flutter) |
| macOS (x64/arm64) | Build from source (Flutter) |

### AI Tool Integration
| Tool | Method | Status |
|------|--------|--------|
| Cursor | MCP (stdio) | Ready |
| Claude Desktop | MCP (stdio) | Ready |
| Claude Code | MCP + Skill | Ready |
| Windsurf | MCP (stdio) | Ready |
| VS Code (Copilot) | MCP (stdio) | Ready |
| Codex CLI | HTTP API | Ready |
| Gemini CLI | HTTP API | Ready |
| OpenAI Agents SDK | HTTP tools | Ready |
| Any HTTP agent | REST API | Ready |

## Contributing

```bash
# Fork & clone
git clone https://github.com/YOUR_USERNAME/openmob.git

# Work on Hub
cd openmob_hub && flutter pub get && flutter run -d linux

# Work on MCP
cd openmob_mcp && npm install && npm run build

# Work on AiBridge
cd openmob_bridge && cargo build
```

## License

MIT License. See [LICENSE](LICENSE).

---

**Built as a free alternative to MobAI.** If AI agents can write code, they should be able to see and test it too — without paying per-tap.
