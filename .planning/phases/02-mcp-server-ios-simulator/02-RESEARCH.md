# Phase 2: MCP Server + iOS Simulator - Research

**Researched:** 2026-03-24
**Domain:** MCP TypeScript SDK, iOS Simulator automation, xcrun simctl, facebook/idb
**Confidence:** HIGH

## Summary

Phase 2 has two deliverables: (1) a TypeScript MCP server (`openmob_mcp/`) that translates MCP tool calls from AI clients into HTTP requests to the Hub API at localhost:8686, and (2) iOS Simulator support added to the Flutter Hub via `xcrun simctl` for lifecycle/screenshots and `facebook/idb` for UI tree inspection and touch simulation.

The MCP server is straightforward -- the official `@modelcontextprotocol/sdk` v1.27.1 provides `McpServer` class with `registerTool()` accepting zod schemas, and `StdioServerTransport` for stdio communication. The server is stateless: every tool call maps to an HTTP request against the existing Hub REST API (GET/POST to localhost:8686/api/v1/devices/...).

iOS Simulator automation has a critical split: `xcrun simctl` handles simulator lifecycle (list/boot/shutdown), screenshots (`xcrun simctl io <udid> screenshot -`), and app management (launch/terminate/openurl). But `xcrun simctl` has **NO support for tap, swipe, type, or accessibility tree inspection**. Those require `facebook/idb` (iOS Development Bridge) which provides `idb ui tap`, `idb ui swipe`, `idb ui text`, `idb ui describe-all` (accessibility tree as JSON), and `idb ui button` (hardware buttons). idb requires `idb_companion` (macOS native, installed via Homebrew) and the `fb-idb` Python client.

**Primary recommendation:** Build MCP server as thin HTTP proxy to Hub. For iOS Simulator, use xcrun simctl for lifecycle/screenshots and idb for UI interaction/accessibility tree. Make idb optional with graceful degradation (screenshot-only mode without idb).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
All implementation choices are at Claude's discretion -- discuss phase was skipped per user setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Key constraints:
- MCP SDK TypeScript (official @modelcontextprotocol/sdk)
- stdio transport (not Streamable HTTP)
- Stateless MCP server -- Hub HTTP API is source of truth
- iOS Simulator via xcrun simctl (macOS only)
- Bind to 127.0.0.1 only for security
- Must expose: list_devices, get_screenshot, get_ui_tree, tap, type_text, swipe, launch_app, terminate_app, press_button, go_home, open_url

### Claude's Discretion
All implementation choices are at Claude's discretion -- discuss phase was skipped per user setting.

### Deferred Ideas (OUT OF SCOPE)
None -- discuss phase skipped.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEV-05 | Connect to iOS simulators via xcrun simctl (macOS only) | xcrun simctl list devices + idb for full automation; Hub needs SimctlService + IdbService |
| UI-03 | Extract UI accessibility tree from iOS simulators | idb ui describe-all returns JSON array of all elements with bounds and accessibility info |
| MCP-01 | MCP server exposes all device tools via stdio transport | McpServer + StdioServerTransport from @modelcontextprotocol/sdk; registerTool with zod schemas |
| MCP-02 | Tool: list_devices | GET /api/v1/devices -> returns device array |
| MCP-03 | Tool: get_screenshot | GET /api/v1/devices/:id/screenshot -> returns base64 PNG; return as MCP image content type |
| MCP-04 | Tool: get_ui_tree | GET /api/v1/devices/:id/ui-tree -> returns nodes array with indices |
| MCP-05 | Tool: tap | POST /api/v1/devices/:id/tap with {x,y} or {index} |
| MCP-06 | Tool: type_text | POST /api/v1/devices/:id/type with {text} |
| MCP-07 | Tool: swipe | POST /api/v1/devices/:id/swipe with {x1,y1,x2,y2,duration} |
| MCP-08 | Tool: launch_app | POST /api/v1/devices/:id/launch with {package} |
| MCP-09 | Tool: terminate_app | POST /api/v1/devices/:id/terminate with {package} |
| MCP-10 | Tool: press_button | POST /api/v1/devices/:id/keyevent with {keyCode} |
| MCP-11 | Tool: go_home | POST /api/v1/devices/:id/keyevent with {keyCode: 3} (Android) or idb ui button HOME (iOS) |
| MCP-12 | Tool: open_url | POST /api/v1/devices/:id/open-url with {url} |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Use ResColors for all UI color management
- Use rxdart instead of setState for state management
- No unnecessary README or documentation files
- No unnecessary tests
- No unnecessary docs or token waste

## Standard Stack

### Core (MCP Server)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| @modelcontextprotocol/sdk | 1.27.1 | MCP protocol | Official SDK. McpServer + StdioServerTransport. Verified on npm. |
| zod | 4.3.6 | Schema validation | Required by MCP SDK for tool input schemas. Verified on npm. |
| typescript | 6.0.2 | Language | Latest stable. MCP SDK is TypeScript-first. Verified on npm. |
| tsx | 4.21.0 | Dev runner | Fast TypeScript execution without build step for development. Verified on npm. |

### Core (iOS Simulator - Hub Side)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| xcrun simctl | Xcode 16+ built-in | Simulator lifecycle, screenshots | Apple's official CLI. No alternative. |
| idb (fb-idb) | latest | UI tree, tap, swipe, type, buttons | Facebook's iOS Dev Bridge. Only tool providing accessibility tree + input simulation for simulators via CLI. |
| idb_companion | latest (Homebrew) | Native macOS companion for idb | Required backend for idb client. Installed via `brew install idb-companion`. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| idb for UI tree | xctree (ldomaradzki) | Swift CLI using macOS Accessibility API. Lighter than idb but less maintained, fewer features (no tap/swipe/type). Not worth splitting tools. |
| idb for tap/swipe | AppleScript + System Events | Fragile, requires Accessibility permissions, coordinate system mismatches. Not reliable for automation. |
| Native fetch | axios/got | fetch is built into Node.js 22+. No reason for HTTP client deps when calling localhost. |

**MCP Server Installation:**
```bash
mkdir openmob_mcp && cd openmob_mcp
npm init -y
npm install @modelcontextprotocol/sdk@^1.27.0 zod@^4.3.0
npm install -D typescript@^6.0.0 @types/node tsx
```

**iOS Simulator Tools (macOS only):**
```bash
# idb_companion (native macOS)
brew tap facebook/fb
brew install idb-companion

# idb client (Python)
pip3 install fb-idb
```

## Architecture Patterns

### MCP Server Project Structure
```
openmob_mcp/
  src/
    index.ts            # Entry point: McpServer + StdioServerTransport + connect
    tools/
      list-devices.ts   # list_devices tool
      screenshot.ts     # get_screenshot tool
      ui-tree.ts        # get_ui_tree tool
      tap.ts            # tap tool
      type-text.ts      # type_text tool
      swipe.ts          # swipe tool
      launch-app.ts     # launch_app tool
      terminate-app.ts  # terminate_app tool
      press-button.ts   # press_button tool
      go-home.ts        # go_home tool
      open-url.ts       # open_url tool
    hub-client.ts       # HTTP client wrapper for Hub API calls
    types.ts            # Shared TypeScript types (Device, UiNode, ActionResult)
  package.json
  tsconfig.json
```

### Hub iOS Service Structure (additions to openmob_hub)
```
openmob_hub/lib/
  services/
    simctl_service.dart    # NEW: xcrun simctl wrapper (list, boot, screenshot)
    idb_service.dart       # NEW: idb wrapper (ui tree, tap, swipe, type, button)
    device_manager.dart    # MODIFIED: add iOS simulator discovery
    screenshot_service.dart # MODIFIED: add iOS screenshot path
    ui_tree_service.dart   # MODIFIED: add iOS UI tree path
    action_service.dart    # MODIFIED: add iOS action path
  models/
    device.dart            # MODIFIED: add platform field (android/ios), device type (simulator/physical)
```

### Pattern 1: MCP Server as Thin HTTP Proxy
**What:** Each MCP tool handler is a single HTTP call to the Hub.
**When to use:** Always. The MCP server NEVER contains device logic.
**Example:**
```typescript
// Source: Official MCP SDK docs + Hub API analysis
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const HUB_URL = "http://127.0.0.1:8686/api/v1";

const server = new McpServer({
  name: "openmob",
  version: "1.0.0",
});

server.registerTool(
  "list_devices",
  {
    description: "List all connected devices (Android and iOS) with metadata",
    inputSchema: {},
  },
  async () => {
    const res = await fetch(`${HUB_URL}/devices`);
    const devices = await res.json();
    return {
      content: [{ type: "text", text: JSON.stringify(devices, null, 2) }],
    };
  }
);

server.registerTool(
  "get_screenshot",
  {
    description: "Capture a screenshot from a device. Returns base64-encoded PNG image.",
    inputSchema: {
      device_id: z.string().describe("Device ID from list_devices"),
    },
  },
  async ({ device_id }) => {
    const res = await fetch(`${HUB_URL}/devices/${device_id}/screenshot`);
    const data = await res.json();
    return {
      content: [
        {
          type: "image" as const,
          data: data.screenshot,
          mimeType: "image/png",
        },
      ],
    };
  }
);

server.registerTool(
  "tap",
  {
    description: "Tap on the device screen at coordinates or by UI element index",
    inputSchema: {
      device_id: z.string().describe("Device ID"),
      x: z.number().optional().describe("X coordinate"),
      y: z.number().optional().describe("Y coordinate"),
      index: z.number().optional().describe("UI element index from get_ui_tree"),
    },
  },
  async ({ device_id, x, y, index }) => {
    const body = index !== undefined ? { index } : { x, y };
    const res = await fetch(`${HUB_URL}/devices/${device_id}/tap`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const result = await res.json();
    return {
      content: [{ type: "text", text: JSON.stringify(result) }],
    };
  }
);

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("OpenMob MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
```

### Pattern 2: Platform-Aware Device Model
**What:** Device model gets a `platform` field to distinguish Android from iOS.
**When to use:** All device operations must check platform to route to correct backend.
**Example:**
```dart
// Hub Device model enhancement
class Device {
  final String platform; // 'android' or 'ios'
  final String deviceType; // 'physical', 'emulator', 'simulator'
  // ... existing fields ...
}
```

### Pattern 3: iOS Simulator Discovery via simctl
**What:** List available iOS simulators using `xcrun simctl list devices -j`.
**When to use:** During device polling cycle in DeviceManager.
**Example:**
```dart
// SimctlService
Future<List<Device>> listSimulators() async {
  final result = await Process.run('xcrun', ['simctl', 'list', 'devices', '-j']);
  final json = jsonDecode(result.stdout as String);
  // json['devices'] is a map of runtime -> list of simulators
  // Each simulator has: udid, name, state, isAvailable, deviceTypeIdentifier
}
```

### Pattern 4: iOS Screenshot via simctl stdout
**What:** Capture screenshot piped to stdout, avoid filesystem.
**When to use:** Always for iOS simulator screenshots.
**Example:**
```dart
// Screenshot to stdout (no temp file)
final result = await Process.run(
  'xcrun', ['simctl', 'io', udid, 'screenshot', '-'],
);
// result.stdout contains raw PNG bytes
final base64 = base64Encode(result.stdout);
```

### Pattern 5: iOS UI Tree via idb
**What:** Use `idb ui describe-all --udid <udid>` to get accessibility tree as JSON.
**When to use:** For get_ui_tree on iOS simulators.
**Example:**
```dart
// IdbService - UI tree
Future<List<UiNode>> getUiTree(String udid) async {
  final result = await Process.run('idb', ['ui', 'describe-all', '--udid', udid]);
  final elements = jsonDecode(result.stdout as String) as List;
  // Each element has: AXLabel, AXFrame {x, y, width, height}, role, AXUniqueId, enabled
  // Map to UiNode with sequential index assignment
}
```

### Pattern 6: iOS Input via idb
**What:** Use idb commands for tap, swipe, type, button press on simulator.
**When to use:** All UI interaction on iOS simulators.
**Commands:**
```
idb ui tap <x> <y> --udid <udid>           # tap at coordinates
idb ui swipe <x1> <y1> <x2> <y2> --udid <udid>  # swipe gesture
idb ui text "<text>" --udid <udid>          # type text
idb ui button HOME --udid <udid>            # press hardware button
idb ui button LOCK --udid <udid>
idb ui button SIDE_BUTTON --udid <udid>
```

### Anti-Patterns to Avoid
- **Direct xcrun/idb from MCP server:** MCP server must ONLY call Hub HTTP API. All xcrun/idb commands execute in the Hub.
- **Using xcrun simctl for tap/swipe:** simctl has NO tap/swipe/type commands. idb is required.
- **Console.log in MCP server:** stdio transport uses stdout for JSON-RPC. ALL logging MUST go to stderr via `console.error()`.
- **Temp files for screenshots:** Use `xcrun simctl io <udid> screenshot -` to pipe to stdout. No temp files.
- **Blocking on idb absence:** idb may not be installed. Gracefully degrade (screenshots work, UI tree returns empty, taps fail with clear error).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MCP protocol | Custom JSON-RPC handler | @modelcontextprotocol/sdk | Protocol is complex with capabilities negotiation, schema validation, transport abstraction |
| iOS accessibility tree | Custom XCUITest wrapper or AppleScript parser | idb ui describe-all | idb handles all the XCTest framework bridging internally, returns clean JSON |
| iOS simulator input | AppleScript click-at-coordinate | idb ui tap/swipe/text | AppleScript is fragile, requires permissions, coordinate systems don't match |
| JSON schema validation | Manual input checking | zod (via MCP SDK) | MCP SDK uses zod natively for tool input validation |
| HTTP client for Hub | axios/got/node-fetch | Native fetch | Built into Node.js 22+, zero dependencies, sufficient for localhost HTTP |

## Common Pitfalls

### Pitfall 1: stdout Corruption in stdio MCP Server
**What goes wrong:** Using console.log() writes to stdout, corrupting JSON-RPC messages between MCP client and server.
**Why it happens:** stdio transport uses stdout for protocol communication.
**How to avoid:** Use `console.error()` for ALL logging. Never use `console.log()`.
**Warning signs:** MCP client fails to connect, garbled responses, "unexpected token" JSON parse errors.

### Pitfall 2: idb Not Installed
**What goes wrong:** UI tree, tap, swipe, type all fail on iOS simulators.
**Why it happens:** idb requires Homebrew + pip install, users may not have it.
**How to avoid:** Check for idb at startup. If absent, log warning. iOS tools that need idb return clear "idb not installed" error. Screenshot and app lifecycle still work via simctl.
**Warning signs:** "command not found: idb" in stderr.

### Pitfall 3: Screenshot Size Exceeding MCP Limits
**What goes wrong:** Claude Desktop has ~1MB limit on tool response content. High-res device screenshots (4K) exceed this.
**Why it happens:** Raw PNG screenshots from modern devices are 2-10MB.
**How to avoid:** Resize/compress screenshots before returning. Target ~800x max dimension or use JPEG compression. The Hub should handle this, not the MCP server.
**Warning signs:** MCP client shows generic error, tool appears to hang.

### Pitfall 4: simctl screenshot Returns Error When Simulator Not Booted
**What goes wrong:** `xcrun simctl io <udid> screenshot -` fails if simulator is not in Booted state.
**Why it happens:** simctl io commands require a running simulator.
**How to avoid:** Check device state before screenshot. Auto-boot if needed or return clear error.
**Warning signs:** Exit code non-zero, stderr contains "Invalid device state".

### Pitfall 5: idb describe-all Returns Empty on Home Screen
**What goes wrong:** Accessibility tree is empty or very limited on iOS home screen and system dialogs.
**Why it happens:** SpringBoard (home screen) has minimal accessibility annotations compared to apps.
**How to avoid:** Document this limitation in tool description. Users should launch an app first.
**Warning signs:** Empty array or array with only 1-2 system elements.

### Pitfall 6: Device ID Mismatch Between Platforms
**What goes wrong:** Android uses serial strings like "emulator-5554" or "R5CR1234567", iOS uses UDIDs like "A1B2C3D4-E5F6-...".
**Why it happens:** Different platform conventions.
**How to avoid:** Use device.id consistently in Hub API. Platform detection based on ID format or stored platform field.
**Warning signs:** "Device not found" errors when passing iOS UDID to ADB or Android serial to simctl.

### Pitfall 7: zod v4 vs v3 Import Differences
**What goes wrong:** MCP SDK official docs show `zod@3` in install but the stack uses `zod@4`.
**Why it happens:** MCP SDK 1.27.x supports both zod 3 and 4.
**How to avoid:** Use zod v4 (4.3.6) as specified in STACK.md. The API is compatible. Import `z` from `"zod"`.
**Warning signs:** Type errors if mixing zod versions.

## Code Examples

### Complete MCP Server Entry Point
```typescript
// src/index.ts
// Source: MCP SDK official docs (modelcontextprotocol.io/docs/develop/build-server)
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const HUB_URL = process.env.OPENMOB_HUB_URL || "http://127.0.0.1:8686/api/v1";

const server = new McpServer({
  name: "openmob",
  version: "1.0.0",
});

// Register all tools here or import from tool files

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("OpenMob MCP Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
```

### Hub Client Helper
```typescript
// src/hub-client.ts
const HUB_URL = process.env.OPENMOB_HUB_URL || "http://127.0.0.1:8686/api/v1";

export async function hubGet(path: string): Promise<any> {
  const res = await fetch(`${HUB_URL}${path}`);
  if (!res.ok) {
    throw new Error(`Hub API error: ${res.status} ${res.statusText}`);
  }
  return res.json();
}

export async function hubPost(path: string, body: Record<string, unknown>): Promise<any> {
  const res = await fetch(`${HUB_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error(`Hub API error: ${res.status} ${res.statusText}`);
  }
  return res.json();
}
```

### Screenshot Tool with Image Return
```typescript
// Source: MCP protocol spec for image content type
server.registerTool(
  "get_screenshot",
  {
    description: "Capture a screenshot from the specified device. Returns the screenshot as an image.",
    inputSchema: {
      device_id: z.string().describe("Device ID from list_devices"),
    },
  },
  async ({ device_id }) => {
    const data = await hubGet(`/devices/${device_id}/screenshot`);
    return {
      content: [
        {
          type: "image" as const,
          data: data.screenshot,  // base64 PNG from Hub
          mimeType: "image/png",
        },
      ],
    };
  }
);
```

### iOS Simulator Discovery (Hub Side)
```dart
// Source: xcrun simctl list devices -j output format
import 'dart:convert';
import 'dart:io';

class SimctlService {
  Future<bool> get isAvailable async {
    try {
      final result = await Process.run('xcrun', ['simctl', 'help']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> listSimulators() async {
    final result = await Process.run(
      'xcrun', ['simctl', 'list', 'devices', '-j'],
    );
    if (result.exitCode != 0) return [];

    final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final devicesMap = json['devices'] as Map<String, dynamic>;
    final simulators = <Map<String, dynamic>>[];

    for (final entry in devicesMap.entries) {
      final runtime = entry.key; // e.g., "com.apple.CoreSimulator.SimRuntime.iOS-17-5"
      final devices = entry.value as List;
      for (final device in devices) {
        final d = device as Map<String, dynamic>;
        if (d['isAvailable'] == true) {
          simulators.add({
            'udid': d['udid'],
            'name': d['name'],
            'state': d['state'],  // "Booted" or "Shutdown"
            'runtime': runtime,
            'deviceType': d['deviceTypeIdentifier'],
          });
        }
      }
    }
    return simulators;
  }

  Future<List<int>> captureScreenshot(String udid) async {
    final result = await Process.run(
      'xcrun', ['simctl', 'io', udid, 'screenshot', '-'],
      stdoutEncoding: null, // raw bytes
    );
    return result.stdout as List<int>;
  }
}
```

### idb Accessibility Tree Parsing
```dart
// Source: fbidb.io/docs/accessibility/
class IdbService {
  Future<bool> get isAvailable async {
    try {
      final result = await Process.run('idb', ['--help']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Returns JSON array of accessibility elements
  /// Each element: {AXLabel, AXFrame: {x,y,width,height}, role, AXUniqueId, enabled}
  Future<List<Map<String, dynamic>>> describeAll(String udid) async {
    final result = await Process.run(
      'idb', ['ui', 'describe-all', '--udid', udid],
    );
    if (result.exitCode != 0) return [];
    return (jsonDecode(result.stdout as String) as List).cast<Map<String, dynamic>>();
  }

  Future<void> tap(String udid, int x, int y) async {
    await Process.run('idb', ['ui', 'tap', '$x', '$y', '--udid', udid]);
  }

  Future<void> swipe(String udid, int x1, int y1, int x2, int y2) async {
    await Process.run('idb', ['ui', 'swipe', '$x1', '$y1', '$x2', '$y2', '--udid', udid]);
  }

  Future<void> typeText(String udid, String text) async {
    await Process.run('idb', ['ui', 'text', text, '--udid', udid]);
  }

  Future<void> pressButton(String udid, String button) async {
    // Supported: HOME, LOCK, SIDE_BUTTON, SIRI, APPLE_PAY
    await Process.run('idb', ['ui', 'button', button, '--udid', udid]);
  }
}
```

### MCP Client Configuration Examples

**Claude Desktop** (`~/Library/Application Support/Claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "openmob": {
      "command": "node",
      "args": ["/absolute/path/to/openmob_mcp/build/index.js"]
    }
  }
}
```

**Cursor** (`~/.cursor/mcp.json` or `<project>/.cursor/mcp.json`):
```json
{
  "mcpServers": {
    "openmob": {
      "command": "node",
      "args": ["/absolute/path/to/openmob_mcp/build/index.js"]
    }
  }
}
```

**VS Code** (`.vscode/settings.json`):
```json
{
  "chat.mcp": {
    "openmob": {
      "command": "node",
      "args": ["/absolute/path/to/openmob_mcp/build/index.js"]
    }
  }
}
```

**Windsurf** (`~/.codeium/windsurf/mcp_config.json`):
```json
{
  "mcpServers": {
    "openmob": {
      "command": "node",
      "args": ["/absolute/path/to/openmob_mcp/build/index.js"]
    }
  }
}
```

## Hub API Contract (Existing from Phase 1)

The MCP server calls these existing Hub endpoints:

| MCP Tool | HTTP Method | Hub Endpoint | Request Body | Response |
|----------|-------------|-------------|--------------|----------|
| list_devices | GET | /api/v1/devices | - | `[{id, serial, model, manufacturer, osVersion, ...}]` |
| get_screenshot | GET | /api/v1/devices/:id/screenshot | - | `{screenshot: "base64...", width, height}` |
| get_ui_tree | GET | /api/v1/devices/:id/ui-tree?text=&visible= | - | `{nodes: [{index, text, className, resourceId, contentDesc, bounds, visible}]}` |
| tap | POST | /api/v1/devices/:id/tap | `{x, y}` or `{index}` | `{success, error?}` |
| type_text | POST | /api/v1/devices/:id/type | `{text}` | `{success, error?}` |
| swipe | POST | /api/v1/devices/:id/swipe | `{x1, y1, x2, y2, duration?}` | `{success, error?}` |
| launch_app | POST | /api/v1/devices/:id/launch | `{package}` | `{success, error?}` |
| terminate_app | POST | /api/v1/devices/:id/terminate | `{package}` | `{success, error?}` |
| press_button | POST | /api/v1/devices/:id/keyevent | `{keyCode}` | `{success, error?}` |
| go_home | POST | /api/v1/devices/:id/keyevent | `{keyCode: 3}` | `{success, error?}` |
| open_url | POST | /api/v1/devices/:id/open-url | `{url}` | `{success, error?}` |

**Note:** For go_home on iOS, the Hub will need to route to `idb ui button HOME` instead of keyevent. The Hub abstracts this -- the MCP server just calls the endpoint.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| MCP SDK separate server/client packages | Single @modelcontextprotocol/sdk package | 2025 | Import from `/server/mcp.js` and `/server/stdio.js` subpaths |
| zod v3 with `.parse()` | zod v4 with 14x faster parsing | 2025 | Compatible API, just faster. MCP SDK works with both. |
| instruments -s devices | xcrun xctrace list devices | Xcode 14 | Old instruments command deprecated |
| Appium for iOS simulator | Direct simctl + idb | 2024-2025 | Lighter, no Java/WDA dependency for simulator-only use |

## Open Questions

1. **idb JSON output format stability**
   - What we know: idb ui describe-all returns JSON with AXLabel, AXFrame, role fields
   - What's unclear: Exact JSON schema across different iOS versions and apps
   - Recommendation: Parse defensively with optional fields, log unknown fields to stderr

2. **Screenshot compression strategy**
   - What we know: Claude Desktop has ~1MB limit on tool responses. Raw 4K screenshots exceed this.
   - What's unclear: Whether Hub should always compress or let MCP server request specific quality
   - Recommendation: Hub compresses iOS screenshots to JPEG quality 80 and max 1280px wide by default. Android screenshots (already handled in Phase 1) may need same treatment.

3. **idb_companion auto-start**
   - What we know: idb_companion must be running for idb commands to work
   - What's unclear: Whether it auto-starts or needs manual launch
   - Recommendation: Check if idb_companion process is running at Hub startup, attempt auto-start if not

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | MCP Server | Yes | v22.16.0 | -- |
| npm | MCP Server deps | Yes | 11.4.2 | -- |
| TypeScript | MCP Server build | Yes (npm) | 6.0.2 (npm) | -- |
| xcrun simctl | iOS Simulator | No (Linux) | -- | iOS features disabled on non-macOS |
| idb | iOS UI tree + input | No (Linux) | -- | iOS limited to screenshots only without idb |
| adb | Android (existing) | Yes | available | -- |

**Missing dependencies with no fallback:**
- None that block execution. iOS features gracefully degrade on non-macOS.

**Missing dependencies with fallback:**
- xcrun simctl: Not available on Linux. iOS simulator features disabled with clear messaging.
- idb: Not available on Linux. Even on macOS, optional. Without it: screenshots work, UI tree/tap/swipe/type return "idb not installed" error.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual validation via MCP Inspector + curl |
| Config file | none |
| Quick run command | `curl http://127.0.0.1:8686/health` |
| Full suite command | MCP Inspector connection test |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MCP-01 | MCP server connects via stdio | smoke | `echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{},"clientInfo":{"name":"test","version":"1.0"},"protocolVersion":"2025-03-26"}}' \| node build/index.js` | Wave 0 |
| MCP-02 | list_devices returns device array | smoke | `curl -s http://127.0.0.1:8686/api/v1/devices` | Existing |
| MCP-03 | get_screenshot returns base64 | smoke | `curl -s http://127.0.0.1:8686/api/v1/devices/{id}/screenshot \| jq .screenshot` | Existing |
| DEV-05 | iOS simulators appear in device list | manual-only | Requires macOS + Xcode + booted simulator | -- |
| UI-03 | iOS accessibility tree extraction | manual-only | Requires macOS + idb + booted simulator with app | -- |

### Sampling Rate
- **Per task commit:** `curl http://127.0.0.1:8686/health` (Hub alive check)
- **Per wave merge:** Full MCP tool exercise via MCP Inspector
- **Phase gate:** All 11 MCP tools respond correctly via MCP Inspector

### Wave 0 Gaps
- None -- no automated test infrastructure needed per project constraints (CLAUDE.md: no unnecessary tests)

## Sources

### Primary (HIGH confidence)
- [MCP TypeScript SDK - server.md](https://github.com/modelcontextprotocol/typescript-sdk/blob/main/docs/server.md) - McpServer API, registerTool, StdioServerTransport
- [MCP Build Server Guide](https://modelcontextprotocol.io/docs/develop/build-server) - Complete TypeScript example with zod schemas
- [@modelcontextprotocol/sdk npm](https://www.npmjs.com/package/@modelcontextprotocol/sdk) - v1.27.1 verified
- [zod npm](https://www.npmjs.com/package/zod) - v4.3.6 verified
- [idb Accessibility Docs](https://fbidb.io/docs/accessibility/) - ui describe-all, describe-point commands
- [idb Commands](https://fbidb.io/docs/commands/) - Full command reference for tap, swipe, text, button, launch, terminate
- [xcrun simctl reference](https://www.iosdev.recipes/simctl/) - Full simctl command reference

### Secondary (MEDIUM confidence)
- [iOS Simulator MCP (whitesmith)](https://github.com/whitesmith/ios-simulator-mcp) - Reference Python MCP server using simctl + idb
- [ios-simulator-skill (openclaw)](https://github.com/openclaw/skills/blob/main/skills/tristanmanchester/ios-simulator/SKILL.md) - Production-ready Claude Code skill for iOS simulator automation
- [MCP Client Config Guide](https://spknowledge.com/2025/06/06/configure-mcp-servers-on-vscode-cursor-claude-desktop/) - Config paths for Claude Desktop, Cursor, VS Code
- [Windsurf MCP Docs](https://docs.windsurf.com/windsurf/cascade/mcp) - Windsurf MCP configuration
- [MCP Image Content Discussion](https://github.com/modelcontextprotocol/modelcontextprotocol/discussions/1204) - Image return format and 1MB limit

### Tertiary (LOW confidence)
- idb_companion auto-start behavior not verified from official docs
- idb ui describe-all exact JSON schema varies by iOS version (inferred from multiple sources)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - MCP SDK v1.27.1 verified on npm, official docs confirm API
- Architecture: HIGH - Hub API contract fully mapped from Phase 1 codebase, MCP proxy pattern well established
- iOS automation: MEDIUM-HIGH - simctl well documented, idb official docs confirm commands but JSON schema needs defensive parsing
- Pitfalls: HIGH - stdout corruption and idb dependency are well-known issues documented across multiple sources

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (MCP SDK stable, simctl stable, idb stable)
