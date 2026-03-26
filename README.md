<p align="center">
  <img src="app-logo.png" alt="OpenMob" width="380">
</p>

<h1 align="center">OpenMob</h1>

<p align="center">
  <strong>Free, self-hosted alternative to <a href="https://mobai.run">MobAI</a> — give AI coding agents the ability to see and control mobile devices.</strong>
</p>

<p align="center">
  No quotas. No daily limits. No cloud dependency. Fully open source.
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#setup-for-ai-tools">AI Tool Setup</a> &bull;
  <a href="#api-reference">API Reference</a> &bull;
  <a href="#manual-installation">Manual Install</a> &bull;
  <a href="openmob_skills/SKILL.md">Skill Reference</a>
</p>

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

### What AI Agents Can Do

| Capability | How |
|-----------|-----|
| **See the screen** | Screenshot capture as base64 PNG |
| **Read UI elements** | Accessibility tree with element indices |
| **Tap buttons** | By element index or x,y coordinates |
| **Type text** | Into any focused input field |
| **Swipe/scroll** | Up, down, left, right with configurable speed |
| **Press keys** | Home, Back, Enter, Volume, Power |
| **Launch/kill apps** | By package name or bundle ID |
| **Open URLs** | Deep links and web URLs |
| **Unlock device** | Wake screen + swipe to dismiss lock |
| **Run tests** | Structured test scripts with pass/fail results |

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

See [Build from Source](#build-from-source) section below.

## Auto-Install

OpenMob Hub **automatically detects missing tools** and offers one-click installation from the **System Check** screen.

| Tool | Auto-Install Method | Manual Install |
|------|-------------------|----------------|
| **ADB** | Downloads from Google (~8MB) | See [Manual ADB Install](#adb) |
| **Node.js** (for MCP) | `winget` (Windows), download (Linux), `brew` (macOS) | See [Manual Node.js Install](#nodejs) |
| **AiBridge** | Downloads from GitHub Releases | See [Manual AiBridge Install](#aibridge) |
| **AI Tool Configs** | One-click setup from System Check screen | See [Setup for AI Tools](#setup-for-ai-tools) |

All tools are stored in `~/.openmob/tools/` — no admin/sudo required.

### If Auto-Install Fails

If the auto-installer doesn't work (network issues, permissions, corporate proxy), install manually:

#### ADB

ADB (Android Debug Bridge) is required for Android device control.

**Windows:**
```powershell
# Option 1: winget (recommended)
winget install Google.PlatformTools

# Option 2: Manual download
# Download from https://developer.android.com/tools/releases/platform-tools
# Extract to C:\platform-tools and add to PATH
```

**Linux:**
```bash
# Ubuntu/Debian
sudo apt install adb

# Arch
sudo pacman -S android-tools

# Fedora
sudo dnf install android-tools

# Manual: download from https://developer.android.com/tools/releases/platform-tools
```

**macOS:**
```bash
brew install android-platform-tools
```

#### Node.js

Node.js is required to run the MCP server (unless using the bundled binary from Releases).

**Windows:**
```powershell
# Option 1: winget
winget install OpenJS.NodeJS.LTS

# Option 2: Download from https://nodejs.org
```

**Linux:**
```bash
# Ubuntu/Debian
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install nodejs

# Or download directly from https://nodejs.org
```

**macOS:**
```bash
brew install node@20
```

After installing Node.js, build the MCP server:
```bash
cd openmob_mcp
npm install
npm run build
```

#### AiBridge

AiBridge is **optional** — only needed if you want to wrap terminal AI agents (Claude Code, Codex, Gemini CLI) with context injection.

**Pre-built binaries:** Download from [Releases](https://github.com/wm-jenildgohel/openmob/releases)

**Build from source (requires Rust):**
```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Build
cd openmob_bridge
cargo build --release

# Binary at: target/release/aibridge (or aibridge.exe on Windows)
```

#### scrcpy (Optional)

scrcpy enables faster screen mirroring. Not required but improves live preview performance.

**Windows:** Download from https://github.com/Genymobile/scrcpy/releases

**Linux:** `sudo apt install scrcpy`

**macOS:** `brew install scrcpy`

#### idb (Optional, macOS only)

Facebook's iOS Development Bridge — needed for iOS Simulator UI tree and interactions.

```bash
brew install idb-companion
pip3 install fb-idb
```

## Setup for AI Tools

OpenMob Hub can **auto-configure your AI tools** from the System Check screen. Just click **"Setup"** or **"Setup All"**.

If you prefer manual setup:

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
curl http://localhost:8686/api/v1/devices/
curl http://localhost:8686/api/v1/devices/{id}/screenshot
curl -X POST http://localhost:8686/api/v1/devices/{id}/tap -d '{"index": 5}'
```

Full API reference in [`openmob_skills/SKILL.md`](openmob_skills/SKILL.md).

## Components

### 1. Hub — Flutter Desktop App (`openmob_hub/`)

The brain. Manages devices, runs the HTTP API, provides the desktop UI.

- **HTTP API** on `localhost:8686` — 16+ REST endpoints for device control
- **Device management** — auto-discovers Android (USB/WiFi/emulator) and iOS Simulators
- **Desktop UI** — device list, live screen preview, process controls, log viewer, test runner
- **Auto-installer** — detects and installs missing tools, configures AI integrations
- **Tech**: Flutter, Dart, shelf HTTP server, rxdart for state management

### 2. MCP Server — TypeScript (`openmob_mcp/`)

The bridge to AI tools. Exposes device tools via [Model Context Protocol](https://modelcontextprotocol.io/).

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

## How It Works

### The See-Think-Act Loop

```
1. AI asks: "What's on screen?"
   → MCP: get_screenshot + get_ui_tree
   → Returns: PNG image + 58 UI elements with indices

2. AI decides: "I need to tap the Login button at index 15"
   → MCP: tap(device_id, index=15)
   → Hub: resolves index to coordinates, runs adb shell input tap

3. AI verifies: "Did the login screen appear?"
   → MCP: get_ui_tree(visible=true)
   → Returns: new elements including "Enter Password" at index 12

4. AI continues: types email, password, taps Submit
   → Full login flow automated without human intervention
```

### Real Example: Testing a Login Flow

Tested live on a real Android device:

| Step | AI Action | Result |
|------|-----------|--------|
| 1 | `launch_app("com.example.myapp")` | App opened |
| 2 | `get_ui_tree(visible=true)` → found "Profile" at index 25 | Read screen |
| 3 | `tap(index=25)` | "Account required" dialog |
| 4 | `tap(index=15)` → "Sign In" | Login screen |
| 5 | `type_text("test@example.com")` | Email entered |
| 6 | `tap(index=16)` → "Using Password" | Password screen |
| 7 | `type_text("Test@1234")` | Password entered |
| 8 | `tap(index=18)` → "Sign In" | "User not found" error caught |

## API Reference

### Devices
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/devices/` | List all connected devices |
| GET | `/api/v1/devices/{id}/screenshot` | Capture screenshot (base64 PNG) |
| GET | `/api/v1/devices/{id}/ui-tree` | Get UI accessibility tree |
| GET | `/api/v1/devices/{id}/ui-tree?visible=true` | Visible elements only |

### Actions
| Method | Endpoint | Body | Description |
|--------|----------|------|-------------|
| POST | `.../tap` | `{"index": N}` or `{"x": 720, "y": 1480}` | Tap element or coordinates |
| POST | `.../type` | `{"text": "hello"}` | Type into focused field |
| POST | `.../swipe` | `{"x1":720,"y1":1800,"x2":720,"y2":800}` | Swipe gesture |
| POST | `.../keyevent` | `{"keyCode": 3}` | Press key (Home=3, Back=4) |
| POST | `.../launch` | `{"package": "com.app"}` | Launch app |
| POST | `.../terminate` | `{"package": "com.app"}` | Kill app |
| POST | `.../open-url` | `{"url": "https://..."}` | Open URL on device |
| POST | `.../unlock` | — | Wake + swipe to unlock |

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
| Auto-install tools | No | No | **Yes** |
| AI tool auto-config | No | No | **Yes** |
| Price | Free (limited) | $99/year | **Free forever** |

## Build from Source

**Prerequisites:**
- **Flutter 3.29.3** — use [FVM](https://fvm.app) for version management
- Node.js 18+ — `node --version`
- Rust 1.70+ — `rustc --version`
- ADB — `adb devices`

```bash
# Install FVM if needed
dart pub global activate fvm

git clone https://github.com/wm-jenildgohel/openmob.git
cd openmob

# Hub (Flutter Desktop)
cd openmob_hub && fvm install && fvm use
fvm flutter pub get && fvm flutter build linux && cd ..
# Windows: fvm flutter build windows

# MCP Server (TypeScript)
cd openmob_mcp && npm install && npm run build && cd ..

# AiBridge (Rust — optional)
cd openmob_bridge && cargo build --release && cd ..

# Run
cd openmob_hub && fvm flutter run -d linux
```

## Supported Platforms

### Device Automation
| Platform | Connection | Screenshot | UI Tree | Interactions |
|----------|-----------|------------|---------|-------------|
| Android (physical) | USB, WiFi ADB | Yes | Yes | Yes |
| Android (emulator) | ADB auto-detect | Yes | Yes | Yes |
| iOS (simulator) | xcrun simctl | Yes | Yes (idb) | Yes (idb) |

### Hub Desktop App
| OS | Status |
|----|--------|
| Linux (x64) | Pre-built binary |
| Windows (x64) | Pre-built binary (via CI) |
| macOS (x64/arm64) | Build from source |

### AI Tool Integration
| Tool | Method | Auto-Config |
|------|--------|------------|
| Cursor | MCP (stdio) | Yes |
| Claude Desktop | MCP (stdio) | Yes |
| Claude Code | MCP + Skill | Yes |
| Windsurf | MCP (stdio) | Yes |
| VS Code (Copilot) | MCP (stdio) | Yes |
| Codex CLI | HTTP API | — |
| Gemini CLI | HTTP API | — |
| OpenAI Agents SDK | HTTP tools | — |

## Project Structure

```
openmob/
├── openmob_hub/          # Flutter Desktop Hub
│   ├── lib/
│   │   ├── core/         # Design system (ResColors, constants)
│   │   ├── models/       # Device, UiNode, TestScript, AiTool
│   │   ├── server/       # shelf HTTP API + routes
│   │   ├── services/     # ADB, DeviceManager, ProcessManager, AiToolSetup
│   │   └── ui/           # Screens + Widgets (rxdart, zero setState)
│   └── assets/           # App logo and icons
├── openmob_mcp/          # MCP Server (TypeScript, SOLID/SRP)
│   └── src/
│       ├── app/          # Bootstrap, server factory
│       ├── mcp/          # common/ + tools/ (device, action, testing)
│       └── types/        # TypeScript interfaces
├── openmob_bridge/       # AiBridge CLI (Rust)
│   └── src/              # PTY, bridge, detector, queue, HTTP server
├── openmob_skills/       # Skill package for AI tools
│   ├── SKILL.md          # Full API reference
│   ├── install.sh        # Auto-detect + install script
│   ├── agents/           # OpenAI Agents SDK definitions
│   └── mcp-configs/      # Ready configs for each AI tool
├── .github/workflows/    # CI/CD — builds all platforms on tag push
└── LICENSE               # MIT
```

## Contributing

```bash
git clone https://github.com/YOUR_USERNAME/openmob.git

cd openmob_hub && flutter pub get && flutter run -d linux  # Hub
cd openmob_mcp && npm install && npm run build             # MCP
cd openmob_bridge && cargo build                           # AiBridge
```

## License

MIT License. See [LICENSE](LICENSE).

---

<p align="center">
  <strong>Built as a free alternative to MobAI.</strong><br>
  If AI agents can write code, they should be able to see and test it too — without paying per-tap.
</p>
