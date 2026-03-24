# Architecture Patterns

**Domain:** AI-powered mobile device automation bridge (OpenMob)
**Researched:** 2026-03-24

## System Overview

OpenMob is a three-component system where each component runs as a separate process on the host machine, communicating over localhost HTTP and stdio pipes. The architecture mirrors the MobAI reference (localhost:8686 HTTP API, stdio MCP, PTY wrapper) but replaces the proprietary desktop app with a Flutter Desktop hub and makes the device bridge layer self-contained rather than SaaS-dependent.

```
+------------------+       stdio        +------------------+
|  AI Agent        | <================> |  AiBridge CLI    |
|  (Claude Code,   |   (PTY wrapped)    |  (Go binary)     |
|   Codex, etc.)   |                    |                  |
+------------------+                    +--------+---------+
                                                 |
                                          HTTP POST /inject
                                          (localhost:9999)
                                                 ^
                                                 |
+------------------+       HTTP/JSON     +-------+----------+
|  MCP Client      | <================> |  MCP Server       |
|  (Cursor, Claude |    stdio pipe      |  (TypeScript)     |
|   Desktop, etc.) |                    |                   |
+------------------+                    +-------+-----------+
                                                |
                                          HTTP REST API
                                         (localhost:8686)
                                                |
                                        +-------+-----------+
                                        |  Flutter Hub      |
                                        |  (Desktop App)    |
                                        |  - Device Manager |
                                        |  - Bridge Control |
                                        |  - HTTP API Server|
                                        +---+----------+----+
                                            |          |
                                      adb commands   xcrun/simctl
                                            |          |
                                    +-------+--+  +----+--------+
                                    | Android  |  | iOS Device/ |
                                    | Device/  |  | Simulator   |
                                    | Emulator |  |             |
                                    +----------+  +-------------+
```

## Component Boundaries

### Component 1: AiBridge CLI (Go)

| Aspect | Detail |
|--------|--------|
| **Language** | Go |
| **Purpose** | Wrap terminal AI agents with PTY, expose HTTP API for context injection |
| **Input** | User terminal input + HTTP POST injection requests |
| **Output** | PTY-wrapped terminal output to user + HTTP status responses |
| **Communicates with** | AI Agent (via PTY stdin/stdout), MCP Server or Hub (receives HTTP injection requests) |
| **Port** | localhost:9999 (configurable) |

**Internal subcomponents:**

| Subcomponent | Responsibility |
|--------------|----------------|
| **CLI Handler** | Cobra-based CLI parsing, flag processing (`--tool`, `--busy-pattern`, `--port`) |
| **PTY Manager** | Spawns child process (AI agent) via `creack/pty`, manages raw terminal mode, propagates SIGWINCH for window resize |
| **HTTP Server** | Exposes `/health`, `/status`, `/inject`, `/queue` endpoints on localhost |
| **Injection Queue** | FIFO queue with priority support, max 100 items, HTTP 429 when full, synchronous mode option |
| **Busy Detector** | Regex pattern matching against terminal output. Default patterns per tool (e.g., "esc to interrupt" for Claude). Agent considered idle after 500ms of pattern absence. Only injects when idle. |

**Key architectural decision:** The PTY wrapper intercepts ALL terminal I/O. The AI agent does not know it is being wrapped -- it sees a normal terminal. This is what makes AiBridge agent-agnostic.

### Component 2: MCP Server (TypeScript)

| Aspect | Detail |
|--------|--------|
| **Language** | TypeScript (Node.js) |
| **Purpose** | Expose mobile device automation as MCP tools for AI coding assistants |
| **Input** | MCP tool calls from client (via stdio transport) |
| **Output** | MCP tool results (screenshots as base64, UI trees as JSON, action confirmations) |
| **Communicates with** | MCP Client (via stdio), Flutter Hub HTTP API (via localhost:8686) |
| **Transport** | stdio (spawned as child process by MCP client) |

**Exposed MCP Tools:**

| Category | Tools |
|----------|-------|
| **Device Management** | `list_devices`, `get_device`, `start_bridge`, `stop_bridge` |
| **Screen Inspection** | `get_screenshot` (returns base64 PNG), `get_ui_tree` (returns accessibility XML/JSON) |
| **UI Actions** | `tap`, `swipe`, `type_text`, `go_home`, `press_back` |
| **App Control** | `launch_app`, `list_apps`, `install_app` |
| **Web Automation** | `web_list_pages`, `web_navigate`, `web_get_dom`, `web_click`, `web_type`, `web_execute_js` |

**Key architectural decision:** Use stdio transport, not Streamable HTTP. The MCP server runs locally alongside the AI client. Stdio eliminates network stack overhead (microsecond latency vs millisecond), requires zero auth configuration, and is the standard for local MCP integrations. Streamable HTTP is only needed for remote/shared deployments -- not our use case.

### Component 3: Flutter Desktop Hub

| Aspect | Detail |
|--------|--------|
| **Language** | Dart/Flutter |
| **Purpose** | Device management UI, process lifecycle management, HTTP API server for device operations |
| **Input** | User GUI interactions + HTTP API requests from MCP Server |
| **Output** | Device state UI + HTTP API responses + ADB/xcrun command execution |
| **Communicates with** | MCP Server (serves HTTP API), ADB daemon (shell commands), iOS toolchain (xcrun/simctl), AiBridge CLI (process lifecycle) |
| **Port** | localhost:8686 (HTTP API) |

**Internal subcomponents:**

| Subcomponent | Responsibility |
|--------------|----------------|
| **HTTP API Server** | RESTful JSON API at localhost:8686. Serves device listing, screenshot capture, UI tree dumps, action execution. This is the central control plane. |
| **Device Manager** | Discovers connected Android/iOS devices via `adb devices` and `xcrun xctrace list devices`. Monitors USB connect/disconnect events. Maintains device registry with connection state. |
| **Bridge Controller** | Manages per-device automation bridges. For Android: ensures ADB connection is active, handles WiFi ADB pairing. For iOS: manages WebDriverAgent or simctl sessions. |
| **Process Manager** | Spawns and manages AiBridge CLI processes. Uses `dart:io Process.start()` with stdin/stdout pipes for lifecycle control. Handles graceful shutdown. |
| **Screenshot Engine** | Captures device screens via `adb exec-out screencap -p` (Android) or `xcrun simctl io screenshot` (iOS simulator). Returns base64-encoded PNG. |
| **UI Tree Engine** | Dumps accessibility trees via `adb shell uiautomator dump` (Android) or accessibility APIs for iOS. Parses XML into structured JSON. |
| **Settings Store** | Persists user configuration (device nicknames, default ports, bridge settings) locally. |

**Key architectural decision:** The Flutter Hub is the central nervous system. It owns the HTTP API that the MCP server consumes. It owns device connections. It manages process lifecycles. This centralization means the MCP server and AiBridge CLI are stateless clients -- they call the Hub and the Hub does the actual device work.

## Data Flow

### Flow 1: MCP Client requests screenshot

```
1. MCP Client (Cursor/Claude Desktop) calls tool "get_screenshot" with device_id
2. MCP Server receives via stdio, makes HTTP GET to Hub: localhost:8686/api/v1/devices/{id}/screenshot
3. Flutter Hub receives request, identifies device platform
4. Hub executes: adb exec-out screencap -p (Android) or xcrun simctl io {udid} screenshot - (iOS)
5. Hub base64-encodes the PNG binary
6. Hub returns JSON: { "screenshot": "base64...", "width": 1080, "height": 2400 }
7. MCP Server wraps response as MCP tool result
8. MCP Client receives and passes to LLM as image content
```

### Flow 2: Context injection into terminal AI agent

```
1. MCP Server (or Hub) captures screenshot + UI tree from device
2. Formats context as text block (UI tree description, screenshot reference)
3. HTTP POST to AiBridge: localhost:9999/inject with body { "text": "...", "priority": true }
4. AiBridge queues injection, waits for Busy Detector to report idle
5. Busy Detector sees 500ms of no "esc to interrupt" pattern
6. AiBridge writes injected text to PTY stdin (as if user typed it)
7. AI Agent (Claude Code) receives the text as "user input" and processes it
8. Response appears in terminal output, visible to both user and Busy Detector
```

### Flow 3: AI agent performs tap action

```
1. LLM decides to call "tap" tool with coordinates {x: 540, y: 1200}
2. MCP Client sends tool call via stdio to MCP Server
3. MCP Server HTTP POST to Hub: localhost:8686/api/v1/devices/{id}/tap
   Body: { "x": 540, "y": 1200 }
4. Hub executes: adb shell input tap 540 1200 (Android)
   Or: simctl/XCUITest coordinate tap for iOS
5. Hub returns success/failure
6. MCP Server returns tool result to client
7. LLM may follow up with get_screenshot to verify the tap worked
```

### Flow 4: Device discovery and bridge startup

```
1. Flutter Hub starts, begins polling: adb devices + xcrun xctrace list devices
2. New device detected, added to device registry with status "discovered"
3. User clicks "Start Bridge" in Hub UI (or MCP tool call start_bridge)
4. Hub verifies ADB connection (or provisions iOS bridge):
   - Android: adb -s {serial} shell getprop (verify responsive)
   - iOS Simulator: xcrun simctl boot {udid} (if needed)
   - iOS Device: setup WebDriverAgent or use devicectl
5. Device status changes to "bridge_active"
6. Hub HTTP API now accepts automation commands for this device
```

## Inter-Component Communication Summary

| From | To | Protocol | Port/Channel | Data Format |
|------|----|----------|-------------|-------------|
| MCP Client | MCP Server | MCP over stdio | stdin/stdout pipe | JSON-RPC 2.0 |
| MCP Server | Flutter Hub | HTTP REST | localhost:8686 | JSON |
| Flutter Hub | ADB Daemon | Shell exec | adb CLI | Text/binary |
| Flutter Hub | iOS Tools | Shell exec | xcrun CLI | Text/binary |
| Flutter Hub | AiBridge CLI | Process spawn | stdin/stdout + lifecycle | Process signals |
| External | AiBridge CLI | HTTP REST | localhost:9999 | JSON |
| AiBridge CLI | AI Agent | PTY | stdin/stdout (wrapped) | Raw terminal bytes |
| User | Flutter Hub | GUI | Native desktop window | User events |
| User | AiBridge CLI | Terminal | stdin (through PTY) | Keyboard input |

## Patterns to Follow

### Pattern 1: Hub as Single Source of Truth for Device State

All device state lives in the Flutter Hub. The MCP server and AiBridge are stateless proxies. If any component crashes, the Hub retains device connections and state. MCP server reconnects and queries current state.

```
BAD:  MCP Server tracks device list independently
GOOD: MCP Server calls Hub's /api/v1/devices every time it needs device info
```

### Pattern 2: Command-Query Separation for Device Operations

Screenshots and UI trees are queries (GET, idempotent, cacheable). Taps, swipes, and typing are commands (POST, side effects, not idempotent). The Hub API should reflect this with proper HTTP verbs and make queries safe to retry.

### Pattern 3: Async Bridge Startup with Status Polling

Bridge startup (especially iOS WebDriverAgent provisioning) can take seconds. Use async pattern: POST returns immediately with a status token, client polls until ready.

```typescript
// MCP Server tool handler
async function startBridge(deviceId: string) {
  const response = await fetch(`${HUB_URL}/api/v1/devices/${deviceId}/bridge`, {
    method: 'POST'
  });
  const { status } = await response.json();

  if (status === 'starting') {
    // Poll until ready
    while (true) {
      const check = await fetch(`${HUB_URL}/api/v1/devices/${deviceId}`);
      const device = await check.json();
      if (device.bridge_status === 'active') return device;
      if (device.bridge_status === 'failed') throw new Error(device.error);
      await sleep(500);
    }
  }
}
```

### Pattern 4: Screenshot Pipeline Optimization

Screenshots are the hottest path. Optimize for latency:

1. Use `adb exec-out screencap -p` (not `adb shell screencap`) to avoid PTY binary corruption
2. Pipe directly to base64 encoder without writing to disk
3. Consider downscaling large screenshots (4K devices) before encoding
4. Cache last screenshot with short TTL for rapid sequential reads

```go
// In Hub's device bridge
cmd := exec.Command("adb", "-s", serial, "exec-out", "screencap", "-p")
output, _ := cmd.Output()
encoded := base64.StdEncoding.EncodeToString(output)
```

### Pattern 5: Graceful Degradation per Platform

iOS automation on non-macOS is impossible (no Xcode). The architecture must degrade gracefully:

- Windows/Linux: Android-only mode, iOS tools return clear "not supported on this platform" errors
- macOS: Full Android + iOS support
- Missing ADB: Android tools disabled with clear error, iOS still works

## Anti-Patterns to Avoid

### Anti-Pattern 1: Direct ADB/xcrun from MCP Server

**What:** MCP Server shells out to `adb` or `xcrun` directly, bypassing the Hub.
**Why bad:** Duplicates device management logic, creates race conditions (two components competing for ADB), makes the MCP server platform-dependent, breaks single-source-of-truth for device state.
**Instead:** All device operations go through the Hub HTTP API. MCP Server is a thin translation layer.

### Anti-Pattern 2: Synchronous Screenshot in Injection Flow

**What:** Blocking the injection queue while waiting for a screenshot to complete.
**Why bad:** Screenshots take 150-500ms on Android. If injection is synchronous, the AI agent stalls.
**Instead:** Screenshot capture and injection are separate operations. The MCP server or orchestrator gathers context asynchronously, then injects when ready.

### Anti-Pattern 3: Persistent WebSocket Connections for Device Events

**What:** Using WebSockets between MCP Server and Hub for real-time device events.
**Why bad:** MCP stdio transport is request-response. The MCP server has no way to push unsolicited events to the AI client. WebSocket complexity adds no value.
**Instead:** Polling-based approach from MCP Server. The Hub can use WebSockets internally for its own UI updates, but the MCP-facing API should be simple REST.

### Anti-Pattern 4: Shared State via Filesystem

**What:** Components communicate by reading/writing files (e.g., screenshot saved to disk, MCP server reads it).
**Why bad:** Race conditions, stale reads, disk I/O bottleneck, cleanup complexity.
**Instead:** All data passes through HTTP responses in-memory (base64 for binary). No temp files in the hot path.

## Build Order (Dependency Chain)

The build order is dictated by hard dependencies. You cannot test upstream without downstream existing.

```
Phase 1: Flutter Hub - HTTP API + Device Management (foundation)
   |
   |-- Hub can be tested standalone with curl/Postman
   |-- ADB device listing, screenshot, UI tree, tap/swipe via REST
   |-- No MCP, no AiBridge needed yet
   |
Phase 2: MCP Server (depends on Hub API)
   |
   |-- Translates MCP tool calls to Hub HTTP calls
   |-- Can be tested with any MCP client (Claude Desktop, Cursor)
   |-- Now AI agents can control devices through MCP
   |
Phase 3: AiBridge CLI (independent, can parallel with Phase 2)
   |
   |-- PTY wrapper + injection HTTP API
   |-- Can be tested standalone with any terminal command
   |-- No device dependency
   |
Phase 4: Integration (Hub + MCP + AiBridge)
   |
   |-- Context injection flow: screenshot -> format -> inject
   |-- End-to-end: AI agent sees device, acts on device
   |-- Hub manages AiBridge process lifecycle
```

**Rationale for this order:**

1. **Hub first** because it is the foundation. Every other component calls the Hub. You cannot test MCP tools without a device API to call. You cannot test injection without context to inject.

2. **MCP Server second** because it has the highest user-visible impact. Once Hub + MCP work, users can control devices from Cursor/Claude Desktop. This is a demo-able milestone.

3. **AiBridge can parallel** because it has zero dependency on device automation. It wraps any terminal command. Build and test it with `echo` or `cat` as the child process.

4. **Integration last** because it ties everything together and requires all components to exist.

## Scalability Considerations

| Concern | 1 Device | 5 Devices | 10+ Devices |
|---------|----------|-----------|-------------|
| ADB connections | Single serial | Must track serials, parallel `adb -s` commands | ADB server may bottleneck; consider connection pooling |
| Screenshot throughput | 150-500ms per capture is fine | Parallel captures across devices | Queue with concurrency limit (ADB has ~5 parallel command limit) |
| Hub HTTP API | Single-threaded handlers OK | Need async/concurrent request handling | Consider isolates or a proper HTTP server (shelf/dart_frog) |
| MCP Server instances | One per MCP client | One per MCP client (each client gets own server) | No scaling concern (each is independent) |
| AiBridge instances | One per AI agent terminal | One per terminal session | No scaling concern (each is independent) |

## Platform-Specific Architecture Notes

### Android Device Bridge

```
Hub -> adb -s {serial} exec-out screencap -p      (screenshot, binary PNG)
Hub -> adb -s {serial} shell uiautomator dump      (UI tree, XML file)
Hub -> adb -s {serial} shell input tap {x} {y}     (tap)
Hub -> adb -s {serial} shell input swipe {args}    (swipe)
Hub -> adb -s {serial} shell input text "{text}"   (type)
Hub -> adb -s {serial} shell am start {intent}     (launch app)
Hub -> adb -s {serial} shell pm list packages      (list apps)
```

ADB uses a client-server architecture: the `adb` CLI talks to the ADB server (TCP port 5037) which talks to the `adbd` daemon on the device. The Hub never talks to `adbd` directly.

WiFi ADB: After initial USB pairing (`adb pair`), the Hub can connect via `adb connect {ip}:{port}` for wireless automation.

### iOS Simulator Bridge

```
Hub -> xcrun simctl list devices          (list simulators)
Hub -> xcrun simctl io {udid} screenshot - (screenshot to stdout)
Hub -> xcrun simctl launch {udid} {bundle} (launch app)
Hub -> xcrun simctl terminate {udid} {bundle}
Hub -> xcrun simctl openurl {udid} {url}
```

For taps and UI inspection on iOS simulators, options are more limited than Android. Consider using `appium-xcuitest-driver` patterns or the `idb` (iOS Development Bridge) tool from Meta for richer automation.

### iOS Physical Device Bridge (macOS only)

Physical iOS devices require WebDriverAgent (maintained by Appium) or Apple's `devicectl`. This is significantly more complex than simulator automation and requires Xcode + signing certificates. Recommend deferring to a later phase.

## Sources

- [MobAI AiBridge (GitHub)](https://github.com/MobAI-App/aibridge) - Reference architecture for PTY wrapper + HTTP injection
- [MobAI MCP Server (GitHub)](https://github.com/MobAI-App/mobai-mcp) - Reference MCP tool set for device automation
- [MobAI Documentation](https://mobai.run/docs/) - HTTP API patterns, bridge architecture
- [MCP TypeScript SDK (GitHub)](https://github.com/modelcontextprotocol/typescript-sdk) - Official MCP server implementation patterns
- [MCP Build Server Guide](https://modelcontextprotocol.io/docs/develop/build-server) - Server architecture and transport options
- [MCP Transport Specification](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports) - stdio vs Streamable HTTP
- [creack/pty (GitHub)](https://github.com/creack/pty) - Go PTY interface for terminal wrapping
- [Android Debug Bridge (Official)](https://developer.android.com/tools/adb) - ADB client-server architecture
- [xcrun simctl Reference](https://www.iosdev.recipes/simctl/) - iOS simulator programmatic control
- [WebDriverAgent (Appium)](https://appium.github.io/appium-xcuitest-driver/4.16/wda-custom-server/) - iOS physical device automation
- [Dart Process API](https://api.flutter.dev/flutter/dart-io/Process/start.html) - Flutter desktop child process management
- [Appium Architecture](https://medium.com/womenintechnology/appium-architecture-44f9e1527e3a) - Mobile automation protocol patterns
