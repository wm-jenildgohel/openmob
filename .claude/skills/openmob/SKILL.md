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

## ADB Knowledge Base

### Common ADB Commands (for direct use or debugging)

| Command | Purpose |
|---------|---------|
| `adb devices -l` | List connected devices with details |
| `adb -s <serial> shell getprop ro.product.model` | Get device model |
| `adb -s <serial> shell getprop ro.build.version.release` | Get Android version |
| `adb -s <serial> shell wm size` | Get screen resolution |
| `adb -s <serial> shell dumpsys battery` | Get battery info |
| `adb -s <serial> shell screencap -p /sdcard/screen.png` | Take screenshot |
| `adb -s <serial> exec-out screencap -p` | Screenshot to stdout (binary-safe) |
| `adb -s <serial> shell uiautomator dump /dev/tty` | Dump UI tree to stdout |
| `adb -s <serial> shell input tap <x> <y>` | Tap at coordinates |
| `adb -s <serial> shell input swipe <x1> <y1> <x2> <y2> <ms>` | Swipe gesture |
| `adb -s <serial> shell input text "<text>"` | Type text |
| `adb -s <serial> shell input keyevent <code>` | Press key |
| `adb -s <serial> shell am start -n <component>` | Start activity |
| `adb -s <serial> shell am force-stop <package>` | Kill app |
| `adb -s <serial> shell am start -a android.intent.action.VIEW -d <url>` | Open URL |
| `adb -s <serial> shell pm list packages -3` | List installed 3rd-party apps |
| `adb -s <serial> shell dumpsys window displays` | Get display info |
| `adb -s <serial> shell settings get system screen_brightness` | Get brightness |
| `adb -s <serial> shell settings get global airplane_mode_on` | Check airplane mode |
| `adb -s <serial> shell cmd connectivity airplane-mode enable/disable` | Toggle airplane |
| `adb -s <serial> shell svc wifi enable/disable` | Toggle WiFi |
| `adb -s <serial> shell svc data enable/disable` | Toggle mobile data |
| `adb -s <serial> shell input keyevent KEYCODE_WAKEUP` | Wake device |
| `adb -s <serial> shell input keyevent KEYCODE_SLEEP` | Sleep device |
| `adb tcpip 5555` | Enable WiFi ADB on device |
| `adb connect <ip>:5555` | Connect via WiFi |
| `adb disconnect <ip>:5555` | Disconnect WiFi device |
| `adb install <apk>` | Install APK |
| `adb uninstall <package>` | Uninstall app |
| `adb push <local> <remote>` | Push file to device |
| `adb pull <remote> <local>` | Pull file from device |
| `adb logcat -d -t 100` | Last 100 logcat lines |
| `adb logcat -d -s <tag>` | Logcat filtered by tag |
| `adb shell dumpsys activity activities` | Current activity stack |
| `adb shell dumpsys meminfo <package>` | Memory usage for app |

### Complete Android Key Codes

| Key | Code | Key | Code | Key | Code |
|-----|------|-----|------|-----|------|
| Home | 3 | Back | 4 | Call | 5 |
| End Call | 6 | 0-9 | 7-16 | Star | 17 |
| Pound | 18 | DPAD Up | 19 | DPAD Down | 20 |
| DPAD Left | 21 | DPAD Right | 22 | DPAD Center | 23 |
| Volume Up | 24 | Volume Down | 25 | Power | 26 |
| Camera | 27 | Clear | 28 | A-Z | 29-54 |
| Comma | 55 | Period | 56 | Alt Left | 57 |
| Alt Right | 58 | Shift Left | 59 | Tab | 61 |
| Space | 62 | Enter | 66 | Backspace | 67 |
| Grave | 68 | Minus | 69 | Equals | 70 |
| Left Bracket | 71 | Right Bracket | 72 | Backslash | 73 |
| Semicolon | 74 | Apostrophe | 75 | Slash | 76 |
| At | 77 | Menu | 82 | Search | 84 |
| Media Play/Pause | 85 | Media Stop | 86 | Media Next | 87 |
| Media Previous | 88 | Page Up | 92 | Page Down | 93 |
| Escape | 111 | Delete | 112 | Scroll Lock | 116 |
| F1-F12 | 131-142 | Mute | 164 | Recent Apps | 187 |
| App Switch | 187 | Brightness Down | 220 | Brightness Up | 221 |
| Screenshot | 120 | Notification | 83 | Settings | 176 |

### iOS Simulator Commands (xcrun simctl)

| Command | Purpose |
|---------|---------|
| `xcrun simctl list devices -j` | List all simulators as JSON |
| `xcrun simctl boot <udid>` | Boot a simulator |
| `xcrun simctl shutdown <udid>` | Shutdown a simulator |
| `xcrun simctl io <udid> screenshot -` | Screenshot to stdout |
| `xcrun simctl launch <udid> <bundleId>` | Launch app |
| `xcrun simctl terminate <udid> <bundleId>` | Kill app |
| `xcrun simctl openurl <udid> <url>` | Open URL |
| `xcrun simctl install <udid> <path.app>` | Install app |
| `xcrun simctl uninstall <udid> <bundleId>` | Uninstall app |
| `xcrun simctl pbpaste <udid>` | Get clipboard content |
| `xcrun simctl pbcopy <udid>` | Set clipboard content |
| `xcrun simctl status_bar <udid> override --time "9:41"` | Override status bar |

### iOS idb Commands (facebook/idb)

| Command | Purpose |
|---------|---------|
| `idb list-targets` | List available devices/simulators |
| `idb ui describe-all --udid <udid>` | Full accessibility tree (JSON) |
| `idb ui tap --udid <udid> <x> <y>` | Tap at coordinates |
| `idb ui swipe --udid <udid> <x1> <y1> <x2> <y2>` | Swipe gesture |
| `idb ui text --udid <udid> "<text>"` | Type text |
| `idb ui button --udid <udid> <button>` | Press button (HOME, LOCK, etc.) |

## Communication Style (IMPORTANT)

When using OpenMob tools, always communicate in **plain English** for non-technical QA testers:

### DO:
- "I tapped the Login button"
- "I typed the email address into the input field"
- "The screen now shows the Dashboard with 3 menu items"
- "I scrolled down to find the Settings option"
- "The login was successful — I can see the Welcome screen"
- "Test failed — the Submit button is not responding. The app might be frozen."

### DON'T:
- "POST /api/v1/devices/abc123/tap {index: 5}"
- "Response: {success: true, data: null}"
- "Executed adb shell input tap 540 1200"
- "UI tree contains 47 nodes with 12 visible elements"

### Every response should include:
1. **What you did** in plain English
2. **What happened** — what you see on screen now
3. **What's next** — what you'll do next and why

### When reporting test results:
- Use pass/fail language, not technical codes
- Include "what went wrong" in human terms for failures
- Suggest what the QA tester should report to the developer

## QA Testing Best Practices

### Before Starting a Test
1. Always call `list_devices` first to get the device ID
2. Take a `screenshot` to verify the device is in the expected state
3. Use `ui-tree?visible=true` to understand the current screen structure

### During Testing
1. **Always verify** — after every action, re-check the UI tree or screenshot
2. **Wait for animations** — add a short delay (1-2 seconds) after navigation actions
3. **Use text search** — `ui-tree?text=ButtonText` to find specific elements
4. **Scroll to find** — if an element isn't visible, scroll and check again
5. **Use element index** — more reliable than coordinates across devices

### Handling Failures
1. Take a screenshot on failure for debugging
2. Check if a dialog/popup appeared (system dialog, permission request)
3. Try pressing Back (keyCode: 4) to dismiss unexpected overlays
4. Verify the app is still running with `list_devices`

### Common Test Scenarios
- **Login flow**: launch → find email field → type → find password field → type → tap login → verify
- **Navigation**: tap menu item → verify new screen → tap back → verify original screen
- **Settings**: open settings → toggle switch → verify change → toggle back
- **Search**: tap search → type query → verify results → tap result → verify detail page
- **Form validation**: submit empty form → verify error messages → fill correctly → submit → verify success

## Tips

- Always use `ui-tree` with `?visible=true` to reduce noise and token usage
- Prefer tapping by `index` over coordinates — more reliable across screen sizes
- After any action, re-fetch ui-tree to verify state changed before proceeding
- Use `keyCode: 4` (Back) to navigate back, `keyCode: 3` (Home) for home screen
- Screenshots are base64 PNG — large on high-res devices, use ui-tree when text is enough
- If an element isn't in the tree, it may be off-screen — scroll first
- Device IDs persist across sessions as long as the device stays connected
