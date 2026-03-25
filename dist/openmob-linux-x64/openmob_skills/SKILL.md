# OpenMob — Mobile Device Automation for AI Agents

> Free, self-hosted alternative to MobAI. See and control Android/iOS devices from any AI coding agent.

## Installation

### For Claude Code

```bash
# Install skill globally (available in all projects)
claude skill add --global /path/to/openmob/.claude/skills/openmob

# Or add to project
claude skill add /path/to/openmob/.claude/skills/openmob
```

### For Cursor / Claude Desktop / Windsurf / VS Code (MCP)

Add to your MCP settings (`~/.cursor/mcp.json`, `claude_desktop_config.json`, etc.):

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

MCP tools available: `list_devices`, `get_screenshot`, `get_ui_tree`, `tap`, `type_text`, `swipe`, `launch_app`, `terminate_app`, `press_button`, `go_home`, `open_url`, `run_test`

### For Codex / Gemini CLI / Any HTTP-capable agent

Point the agent to the Hub API at `http://127.0.0.1:8686`. Provide this skill file as context.

### For OpenAI Agents SDK / Custom Agents

```yaml
# agents/openmob.yaml
name: openmob-device-controller
description: Controls mobile devices via OpenMob Hub API
tools:
  - type: http
    base_url: http://127.0.0.1:8686/api/v1
    endpoints:
      - GET /devices/
      - GET /devices/{id}/screenshot
      - GET /devices/{id}/ui-tree
      - POST /devices/{id}/tap
      - POST /devices/{id}/type
      - POST /devices/{id}/swipe
      - POST /devices/{id}/keyevent
      - POST /devices/{id}/launch
      - POST /devices/{id}/terminate
      - POST /devices/{id}/open-url
      - POST /devices/{id}/gesture
```

## Prerequisites

1. **OpenMob Hub** must be running: `cd openmob_hub && flutter run -d linux`
2. **Android device** connected via USB or WiFi ADB, OR **iOS Simulator** on macOS
3. **ADB** installed (for Android): `sudo apt install adb` / `brew install android-platform-tools`
4. **Node.js 18+** (for MCP server only): `sudo apt install nodejs` / `brew install node`

## Hub API Reference

Base URL: `http://127.0.0.1:8686`

### Device Discovery

| Method | Endpoint | Body | Returns |
|--------|----------|------|---------|
| GET | `/api/v1/devices/` | — | Array of connected devices with id, model, OS, screen size, battery, platform |

### Screen & UI

| Method | Endpoint | Body | Returns |
|--------|----------|------|---------|
| GET | `/api/v1/devices/{id}/screenshot` | — | `{ screenshot: "<base64 PNG>", width, height }` |
| GET | `/api/v1/devices/{id}/ui-tree` | — | `{ nodes: [{ index, text, className, resourceId, contentDesc, bounds, visible }] }` |
| GET | `/api/v1/devices/{id}/ui-tree?visible=true` | — | Filtered to visible elements only |
| GET | `/api/v1/devices/{id}/ui-tree?text=Settings` | — | Filtered by text regex |

### Interactions

| Method | Endpoint | Body | Returns |
|--------|----------|------|---------|
| POST | `/api/v1/devices/{id}/tap` | `{ "x": 720, "y": 1480 }` | `{ success: true }` |
| POST | `/api/v1/devices/{id}/tap` | `{ "index": 8 }` | Tap element #8 from ui-tree |
| POST | `/api/v1/devices/{id}/type` | `{ "text": "hello" }` | Type into focused field |
| POST | `/api/v1/devices/{id}/swipe` | `{ "x1": 720, "y1": 1800, "x2": 720, "y2": 800, "duration": 300 }` | Swipe gesture |
| POST | `/api/v1/devices/{id}/keyevent` | `{ "keyCode": 3 }` | Press hardware key |
| POST | `/api/v1/devices/{id}/launch` | `{ "package": "com.android.settings" }` | Launch app |
| POST | `/api/v1/devices/{id}/terminate` | `{ "package": "com.android.settings" }` | Kill app |
| POST | `/api/v1/devices/{id}/open-url` | `{ "url": "https://google.com" }` | Open URL on device |
| POST | `/api/v1/devices/{id}/gesture` | `{ "type": "longpress", "x": 720, "y": 1480, "duration": 1000 }` | Long press, pinch, etc. |
| GET | `/health` | — | `{ status: "ok" }` |

### Key Codes

| Key | Code | Key | Code |
|-----|------|-----|------|
| Home | 3 | Back | 4 |
| Enter | 66 | Backspace | 67 |
| Volume Up | 24 | Volume Down | 25 |
| Power | 26 | Recent Apps | 187 |
| Tab | 61 | Escape | 111 |
| Menu | 82 | Delete | 112 |

### Swipe Directions

| Direction | Body |
|-----------|------|
| Scroll up | `{ "x1": 720, "y1": 1800, "x2": 720, "y2": 800 }` |
| Scroll down | `{ "x1": 720, "y1": 800, "x2": 720, "y2": 1800 }` |
| Swipe left | `{ "x1": 1200, "y1": 1480, "x2": 200, "y2": 1480 }` |
| Swipe right | `{ "x1": 200, "y1": 1480, "x2": 1200, "y2": 1480 }` |

## Workflow Patterns

### Pattern 1: See-Think-Act Loop (QA Testing)

```
1. GET /api/v1/devices/              → discover device, get ID
2. GET /api/v1/devices/{id}/screenshot   → see what's on screen
3. GET /api/v1/devices/{id}/ui-tree?visible=true  → read all UI elements
4. POST /api/v1/devices/{id}/tap     → interact based on what you see
5. GET /api/v1/devices/{id}/ui-tree?visible=true  → verify result
6. Repeat 2-5 for each test step
```

### Pattern 2: App Launch + Navigate + Assert

```
1. POST /launch  {"package":"com.myapp"}     → open the app
2. GET /ui-tree?visible=true                  → read initial screen
3. POST /tap  {"index": N}                    → tap target element
4. GET /ui-tree?visible=true                  → verify navigation happened
5. Assert: check that expected text/elements exist in the tree
```

### Pattern 3: Form Fill

```
1. GET /ui-tree?visible=true                  → find input fields
2. POST /tap  {"index": N}                    → focus first input
3. POST /type  {"text":"user@email.com"}      → type email
4. POST /keyevent  {"keyCode": 61}            → Tab to next field
5. POST /type  {"text":"password123"}         → type password
6. POST /tap  {"index": M}                    → tap Submit button
7. GET /ui-tree?visible=true                  → verify success screen
```

### Pattern 4: Scroll to Find Element

```
1. GET /ui-tree?text=TargetText               → search for element
2. If not found:
   POST /swipe  {"x1":720,"y1":1800,"x2":720,"y2":800}  → scroll up
   GET /ui-tree?text=TargetText               → search again
3. Repeat until found or max scrolls reached
4. POST /tap  {"index": found_index}          → tap the element
```

### Pattern 5: Run Test Script (via MCP)

```
MCP tool: run_test
Input: {
  "device_id": "abc123",
  "name": "Login flow test",
  "steps": [
    { "action": "launch_app", "params": {"package":"com.myapp"}, "description": "Open app" },
    { "action": "tap", "params": {"index": 5}, "description": "Tap login button" },
    { "action": "type_text", "params": {"text":"user@test.com"}, "description": "Enter email" },
    { "action": "tap", "params": {"index": 8}, "assertion": {"type":"element_exists","text":"Welcome"} }
  ]
}
Returns: structured pass/fail with timing and failure screenshots
```

## Architecture

```
                    AI Agent (Claude Code / Cursor / Codex / Gemini)
                         │
            ┌────────────┼────────────┐
            │            │            │
    MCP (stdio)   HTTP API (:8686)  AiBridge (:9999)
            │            │            │
            └────────────┼────────────┘
                         │
                   OpenMob Hub (Flutter Desktop)
                         │
              ┌──────────┼──────────┐
              │                     │
        ADB (Android)      xcrun/idb (iOS)
              │                     │
        Physical Device      iOS Simulator
        / Emulator
```

- **Hub** (port 8686): Core — device management, HTTP API, desktop UI
- **MCP Server** (stdio): Thin proxy — translates MCP tool calls to Hub HTTP API
- **AiBridge** (port 9999): Optional — wraps terminal AI agents with context injection

## Tips

- Always use `ui-tree` with `?visible=true` to reduce noise and token usage
- Prefer tapping by `index` over coordinates — more reliable across screen sizes
- After any action, re-fetch ui-tree to verify state changed before proceeding
- Use `keyCode: 4` (Back) to navigate back, `keyCode: 3` (Home) for home screen
- Screenshots are base64 PNG — large on high-res devices, use ui-tree when text is enough
- If an element isn't in the tree, it may be off-screen — scroll first
- Device IDs persist across sessions as long as the device stays connected
