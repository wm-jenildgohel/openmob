# OpenMob — Mobile Device Automation for AI Agents

> Free, self-hosted alternative to MobAI. See and control Android/iOS devices from any AI coding agent.
> **34 MCP tools** — device control, app management, testing, debugging, and more.

## Install

### Option 1: OpenMob Hub (recommended — auto-installs everything)
Download from [GitHub Releases](https://github.com/wm-jenildgohel/openmob/releases) and run. The Hub automatically:
- Installs the MCP server config for Claude Desktop, Cursor, VS Code, Windsurf
- Installs the skill file for Claude Code, Codex CLI, Gemini CLI
- No manual setup needed

### Option 2: MCP Server only (any AI tool with MCP support)
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
Add this to your AI tool's MCP config:
- **Claude Desktop**: `~/Library/Application Support/Claude/claude_desktop_config.json` (Mac) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows)
- **Cursor**: `~/.cursor/mcp.json`
- **VS Code**: `.vscode/mcp.json` in your project
- **Windsurf**: `~/.windsurf/mcp.json`

### Option 3: Claude Code skill (for terminal agents)
```bash
# Install from GitHub
claude mcp add openmob -- npx -y openmob-mcp

# Or install the skill file for richer context
git clone https://github.com/wm-jenildgohel/openmob.git
claude skill add --global openmob/.claude/skills/openmob
```

### Option 4: Codex CLI / Gemini CLI
Copy the skill content to your agent's instruction file:
- **Codex**: `~/.codex/AGENTS.md`
- **Gemini**: `~/.gemini/GEMINI.md`

### For Codex / Gemini CLI / Any HTTP Agent
Point to Hub API: `http://127.0.0.1:8686`

### For OpenAI Agents SDK
```yaml
name: openmob-device-controller
tools:
  - type: http
    base_url: http://127.0.0.1:8686/api/v1
```

## Prerequisites

1. **OpenMob Hub** running (auto-starts on launch)
2. **Android device** via USB/WiFi or emulator, OR **iOS Simulator** on macOS
3. **ADB** installed (Hub auto-detects and guides installation)
4. **Node.js 18+** (for MCP server — Hub can auto-install)

## All 26 MCP Tools

### Device Discovery (3 tools)

| Tool | What it does | Key params |
|------|-------------|------------|
| `list_devices` | See all connected devices with model, OS, screen size, battery | — |
| `get_screenshot` | Take a photo of what's on the device screen | `device_id` |
| `get_ui_tree` | Read all buttons, text, fields on screen with index numbers | `device_id`, `text_filter?`, `visible_only?` |

### Touch & Input (7 tools)

| Tool | What it does | Key params |
|------|-------------|------------|
| `tap` | Tap a button or position on screen | `device_id`, `index` or `x,y` |
| `type_text` | Type text into a focused input field | `device_id`, `text` |
| `swipe` | Scroll or swipe in a direction | `device_id`, `direction` or `x1,y1,x2,y2` |
| `press_button` | Press Home/Back/Volume/Power/Enter | `device_id`, `key_code` |
| `go_home` | Go to the home screen | `device_id` |
| `open_url` | Open a website or deep link | `device_id`, `url` |
| `install_app` | Install an APK from a file path | `device_id`, `path` |

### App Management (5 tools)

| Tool | What it does | Key params |
|------|-------------|------------|
| `launch_app` | Open an app by package name | `device_id`, `package` |
| `terminate_app` | Close/kill a running app | `device_id`, `package` |
| `uninstall_app` | Remove an app from the device | `device_id`, `package` |
| `list_apps` | List all installed apps | `device_id`, `third_party_only?` |
| `clear_app_data` | Reset an app (like fresh install) | `device_id`, `package` |

### Device Info & Settings (6 tools)

| Tool | What it does | Key params |
|------|-------------|------------|
| `get_current_activity` | See which app/screen is open now | `device_id` |
| `get_device_logs` | Read device logs (logcat) for debugging | `device_id`, `lines?`, `tag?`, `level?` |
| `get_notifications` | Read the notification bar | `device_id` |
| `set_rotation` | Rotate screen (portrait/landscape) | `device_id`, `rotation` (0-3) |
| `toggle_wifi` | Turn WiFi on/off | `device_id`, `enabled` |
| `toggle_airplane_mode` | Turn airplane mode on/off | `device_id`, `enabled` |

### Testing & Verification (3 tools)

| Tool | What it does | Key params |
|------|-------------|------------|
| `wait_for_element` | Wait until a button/text appears on screen | `device_id`, `text?`, `resource_id?`, `timeout_ms?` |
| `grant_permissions` | Auto-grant all app permissions (skip popups) | `device_id`, `package` |
| `run_test` | Run a multi-step test scenario with pass/fail | `device_id`, `name`, `steps[]` |

## Hub HTTP API Reference

Base URL: `http://127.0.0.1:8686`

### Device Endpoints

| Method | Endpoint | Body | Returns |
|--------|----------|------|---------|
| GET | `/api/v1/devices/` | — | Array of devices |
| GET | `/api/v1/devices/{id}/screenshot` | — | `{ screenshot, width, height }` |
| GET | `/api/v1/devices/{id}/ui-tree` | — | `{ nodes: [{ index, text, className, bounds, visible }] }` |
| GET | `/api/v1/devices/{id}/apps` | — | `{ packages, count }` |
| GET | `/api/v1/devices/{id}/current-activity` | — | `{ package, activity }` |
| GET | `/api/v1/devices/{id}/logcat` | — | `{ lines, count }` |
| GET | `/api/v1/devices/{id}/notifications` | — | `{ notifications, count }` |

### Action Endpoints

| Method | Endpoint | Body | Returns |
|--------|----------|------|---------|
| POST | `/api/v1/devices/{id}/tap` | `{ x, y }` or `{ index }` | `{ success }` |
| POST | `/api/v1/devices/{id}/type` | `{ text }` | `{ success }` |
| POST | `/api/v1/devices/{id}/swipe` | `{ direction }` or `{ x1, y1, x2, y2, duration }` | `{ success }` |
| POST | `/api/v1/devices/{id}/keyevent` | `{ keyCode }` | `{ success }` |
| POST | `/api/v1/devices/{id}/launch` | `{ package }` | `{ success }` |
| POST | `/api/v1/devices/{id}/terminate` | `{ package }` | `{ success }` |
| POST | `/api/v1/devices/{id}/open-url` | `{ url }` | `{ success }` |
| POST | `/api/v1/devices/{id}/install` | `{ path, replace?, grant_permissions? }` | `{ success }` |
| POST | `/api/v1/devices/{id}/uninstall` | `{ package }` | `{ success }` |
| POST | `/api/v1/devices/{id}/clear-data` | `{ package }` | `{ success }` |
| POST | `/api/v1/devices/{id}/rotation` | `{ rotation }` | `{ success }` |
| POST | `/api/v1/devices/{id}/wifi` | `{ enabled }` | `{ success }` |
| POST | `/api/v1/devices/{id}/airplane` | `{ enabled }` | `{ success }` |
| POST | `/api/v1/devices/{id}/grant-permissions` | `{ package }` | `{ success }` |
| POST | `/api/v1/devices/{id}/wait-for-element` | `{ text?, resource_id?, timeout_ms }` | `{ found, index, waitedMs }` |
| POST | `/api/v1/devices/{id}/gesture` | `{ type, x, y, duration }` | `{ success }` |
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

Use `direction` parameter for simple swipes:
| Direction | Effect |
|-----------|--------|
| `"up"` | Scroll down (reveals content below) |
| `"down"` | Scroll up (reveals content above) |
| `"left"` | Swipe left (next page) |
| `"right"` | Swipe right (previous page) |

Or use coordinates for precise control: `{ x1, y1, x2, y2, duration }`

## Workflow Patterns

### Pattern 1: See-Think-Act Loop (QA Testing)
```
1. list_devices               → find the device
2. get_screenshot              → see what's on screen
3. get_ui_tree (visible=true)  → read UI elements
4. tap / type_text / swipe     → interact
5. get_ui_tree (visible=true)  → verify result
6. Repeat 2-5 for each step
```

### Pattern 2: App Launch + Test
```
1. launch_app → open the app
2. wait_for_element → wait for main screen to load
3. get_ui_tree → read the screen
4. tap/type/swipe → perform test actions
5. get_screenshot → capture result
```

### Pattern 3: Login Flow
```
1. launch_app → open the app
2. wait_for_element text="Email" → wait for login screen
3. tap index=N → focus email field
4. type_text "user@test.com" → enter email
5. press_button 61 (Tab) → move to password
6. type_text "password123" → enter password
7. tap index=M → tap Login button
8. wait_for_element text="Welcome" → verify success
```

### Pattern 4: Fresh Install Test
```
1. uninstall_app → remove old version
2. install_app path="/path/to/app.apk" → install fresh
3. grant_permissions → skip permission popups
4. launch_app → open the app
5. ... run test steps
```

### Pattern 5: Debug a Crash
```
1. launch_app → open the app
2. ... reproduce the crash steps
3. get_device_logs tag="AndroidRuntime" level="error" → get crash logs
4. get_screenshot → capture error state
```

### Pattern 6: Network Testing
```
1. toggle_wifi enabled=false → disconnect WiFi
2. ... test offline behavior
3. toggle_wifi enabled=true → reconnect
4. ... verify reconnection handling
```

### Pattern 7: Rotation Testing
```
1. set_rotation 0 → portrait
2. get_screenshot → capture portrait layout
3. set_rotation 1 → landscape
4. get_screenshot → capture landscape layout
5. Compare both screenshots for layout issues
```

### Pattern 8: Run Automated Test
```
run_test with steps:
  - launch_app
  - wait_for_element text="Login"
  - tap index=5
  - type_text "test@email.com"
  - tap index=8 + assertion: element_exists "Welcome"
Returns: pass/fail with timing and failure screenshots
```

## Communication Style (IMPORTANT)

When using OpenMob, communicate in **plain English** for non-technical QA testers:

### DO:
- "I tapped the Login button"
- "I typed the email address into the input field"
- "The screen now shows the Dashboard with 3 menu items"
- "Test passed — the user can successfully log in and see the Welcome screen"
- "Test failed — the Submit button is not responding. The app might be frozen."

### DON'T:
- "POST /api/v1/devices/abc123/tap {index: 5}"
- "Response: {success: true}"
- "UI tree contains 47 nodes"

### Every response should include:
1. **What you did** in plain English
2. **What happened** — what you see on screen now
3. **What's next** — what you'll do next and why

## QA Testing Best Practices

### Before Starting
1. Call `list_devices` to get the device ID
2. Take a `screenshot` to verify device state
3. Use `grant_permissions` for the app under test to avoid popup interruptions

### During Testing
1. **Always verify** — after every action, check ui-tree or screenshot
2. **Use `wait_for_element`** after navigation — don't assume instant transitions
3. **Use element index** — more reliable than coordinates
4. **Use `visible_only: true`** on ui-tree to reduce noise
5. **Scroll to find** — if element isn't visible, swipe then check again

### Handling Failures
1. Take a screenshot on failure
2. Check `get_device_logs` for crash info
3. Press Back (key 4) to dismiss unexpected dialogs
4. Check `get_notifications` for system alerts
5. Check `get_current_activity` to see if the right app is in foreground

### Common Scenarios
- **Login flow**: launch → find email → type → find password → type → tap login → verify
- **Navigation**: tap menu → verify screen → back → verify return
- **Settings**: open settings → toggle → verify → toggle back
- **Search**: tap search → type query → verify results → tap result → verify detail
- **Form validation**: submit empty → verify errors → fill correctly → submit → verify success
- **Offline mode**: disable WiFi → test behavior → enable WiFi → verify recovery
- **Rotation**: test portrait → rotate → test landscape → verify no layout issues

## Architecture

```
                AI Agent (Claude / Cursor / Codex / Gemini)
                     │
        ┌────────────┼────────────┐
        │            │            │
 MCP (stdio)   HTTP API      AiBridge
   26 tools     (:8686)       (:9999)
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
- **MCP Server** (stdio): 26 tools — translates MCP calls to Hub API
- **AiBridge** (port 9999): Optional — wraps terminal AI agents with context injection

## Tips

- Use `ui-tree` with `visible_only: true` to reduce noise and token usage
- Prefer `index` over coordinates — works across screen sizes
- Use `wait_for_element` instead of guessing delays after navigation
- Use `clear_app_data` + `launch_app` for clean test states
- Use `grant_permissions` before tests to avoid permission popup interruptions
- Device IDs persist as long as the device stays connected
- Screenshots are base64 PNG — use ui-tree when text is enough
- Use `get_device_logs` to debug crashes instead of guessing
