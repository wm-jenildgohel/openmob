# OpenMob — Mobile Device Automation for AI Agents

You have access to OpenMob, a tool that lets you see and control mobile devices (Android/iOS). Use it to test apps, verify UI, automate interactions, and run QA scenarios.

## Quick Start

The Hub must be running on `http://127.0.0.1:8686`. All endpoints return JSON.

## API Reference

### Device Discovery

```bash
# List all connected devices
GET /api/v1/devices/
# Returns: [{ id, serial, model, manufacturer, osVersion, sdkVersion, screenWidth, screenHeight, batteryLevel, connectionType, status, platform }]
```

### Screen Capture

```bash
# Take screenshot (returns base64 PNG)
GET /api/v1/devices/<id>/screenshot
# Returns: { screenshot: "<base64>", width: 1440, height: 2960 }
```

### UI Tree (Accessibility)

```bash
# Get all UI elements with indices
GET /api/v1/devices/<id>/ui-tree
# Optional query params: ?text=regex&visible=true
# Returns: { nodes: [{ index, text, className, resourceId, contentDesc, bounds: { left, top, right, bottom, centerX, centerY }, visible }] }
```

Use `?visible=true` to filter to visible elements only. Use `?text=Settings` to filter by text.

### Device Interactions

```bash
# Tap at coordinates
POST /api/v1/devices/<id>/tap
Body: { "x": 720, "y": 1480 }

# Tap by UI element index (from ui-tree)
POST /api/v1/devices/<id>/tap
Body: { "index": 8 }

# Type text into focused field
POST /api/v1/devices/<id>/type
Body: { "text": "hello world" }

# Swipe gesture
POST /api/v1/devices/<id>/swipe
Body: { "x1": 720, "y1": 1800, "x2": 720, "y2": 800, "duration": 300 }
# Swipe up: y1 > y2 | Swipe down: y1 < y2 | Swipe left: x1 > x2 | Swipe right: x1 < x2

# Press hardware key
POST /api/v1/devices/<id>/keyevent
Body: { "keyCode": 3 }
# Key codes: Home=3, Back=4, Enter=66, VolumeUp=24, VolumeDown=25, Power=26, RecentApps=187

# Launch app
POST /api/v1/devices/<id>/launch
Body: { "package": "com.android.settings" }

# Terminate app
POST /api/v1/devices/<id>/terminate
Body: { "package": "com.android.settings" }

# Open URL / deep link
POST /api/v1/devices/<id>/open-url
Body: { "url": "https://google.com" }

# Advanced gesture (long press, pinch)
POST /api/v1/devices/<id>/gesture
Body: { "type": "longpress", "x": 720, "y": 1480, "duration": 1000 }
```

### Health Check

```bash
GET /health
# Returns: { "status": "ok" }
```

## Workflow Pattern for QA Testing

1. **Discover devices**: `GET /api/v1/devices/` → pick device ID
2. **Screenshot**: `GET /api/v1/devices/<id>/screenshot` → see current screen
3. **Read UI tree**: `GET /api/v1/devices/<id>/ui-tree?visible=true` → find elements by text/index
4. **Interact**: tap, type, swipe using element indices or coordinates
5. **Verify**: screenshot + ui-tree again to confirm the action worked

### Example: Open Settings and tap Wi-Fi

```
1. GET /api/v1/devices/<id>/ui-tree?visible=true  → find "Settings" icon index
2. POST /api/v1/devices/<id>/launch  {"package":"com.android.settings"}
3. GET /api/v1/devices/<id>/ui-tree?visible=true  → find "Network & internet" index
4. POST /api/v1/devices/<id>/tap  {"index": 24}
5. GET /api/v1/devices/<id>/screenshot  → verify Wi-Fi settings opened
```

## MCP Server (for MCP-compatible AI tools)

If using Cursor, Claude Desktop, Windsurf, or VS Code with MCP support:

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

Available MCP tools: `list_devices`, `get_screenshot`, `get_ui_tree`, `tap`, `type_text`, `swipe`, `launch_app`, `terminate_app`, `press_button`, `go_home`, `open_url`, `run_test`

## Tips

- Always use `ui-tree` with `?visible=true` to reduce noise
- Prefer tapping by `index` over coordinates — more reliable across screen sizes
- After any action, wait briefly then re-fetch ui-tree to verify state changed
- Screenshots are base64 PNG — decode to view
- Use `keyCode: 4` (Back) to navigate back in Android apps
- Use `keyCode: 3` (Home) to go to home screen
