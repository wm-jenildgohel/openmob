# Feature Landscape

**Domain:** AI-powered mobile device automation bridge (connecting AI coding agents to mobile devices)
**Researched:** 2026-03-24
**Competitors analyzed:** MobAI (mobai.run), mobile-next/mobile-mcp (4.1k stars), Appium MCP, DroidRun (3.8k stars)

---

## Table Stakes

Features users expect from any tool in this category. Missing any of these and users will not adopt.

### Device Management

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| List connected devices | Every competitor has it; users need to know what's available | Low | ADB devices + xcrun simctl list; JSON output required |
| Connect to Android via ADB (USB) | Primary Android connection method | Low | Shell out to `adb devices` |
| Connect to Android Emulator | Developers test on emulators constantly | Low | Same ADB interface, auto-detected |
| Connect to iOS Simulator | Primary iOS dev workflow | Med | `xcrun simctl` commands, macOS only |
| Connect to Android via WiFi ADB | Convenience for untethered development | Low | `adb tcpip` + `adb connect`; ADB handles natively |
| Device info retrieval (model, OS, screen size) | Users need context about their devices; AI agents use this for decisions | Low | ADB props / simctl device info |
| Start/stop device automation bridge | MobAI has this; needed to manage per-device agent lifecycle | Med | Lifecycle management for ADB shell / WDA sessions |

### Screen Capture and UI Inspection

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Screenshot capture | THE core feature -- AI agents need to "see" the screen | Low | `adb exec-out screencap` / `xcrun simctl io screenshot` |
| Screenshot as base64 | MCP tools pass images inline to LLMs | Low | Encode after capture |
| UI accessibility tree extraction | Structured understanding of screen elements; all competitors provide this | Med | `uiautomator dump` on Android; simctl accessibility on iOS simulator |
| Element indices in UI tree | AI agents need to reference specific elements for tap/type | Med | Parse XML, assign stable indices per snapshot |
| UI tree filtering (text regex, bounds, visibility) | Large UI trees overwhelm LLM context windows; filtering reduces noise | Med | Regex/bounds filtering on parsed tree data |

### Device Interaction

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Tap at coordinates | Most basic interaction primitive | Low | `adb shell input tap x y` / simctl equivalent |
| Tap by element index | Higher-level than coordinates; reduces AI error rate significantly | Med | Resolve index from UI tree, then tap center of bounds |
| Type text into focused field | Form filling, search, any text input | Low | `adb shell input text` / simctl keyboard input |
| Swipe gesture (up/down/left/right) | Scrolling, navigation, pull-to-refresh | Low | `adb shell input swipe` with configurable coordinates and duration |
| Press hardware keys (Home, Back, Enter, Volume) | Navigation, dismissing dialogs, Android back button essential | Low | `adb shell input keyevent KEYCODE_*` |
| Go to home screen | Basic navigation reset | Low | Home key event shortcut |
| Launch app by package/bundle ID | Starting the app under test | Low | `adb shell am start` / `xcrun simctl launch` |
| Terminate/kill app | Resetting app state, switching contexts | Low | `adb shell am force-stop` / `xcrun simctl terminate` |
| Open URL / deep link on device | Navigate directly to specific app screens | Low | `adb shell am start -a VIEW -d URL` / `xcrun simctl openurl` |

### MCP Server Integration

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| MCP server exposing device tools via stdio | MCP is THE standard for AI tool integration in 2026; adopted by Anthropic, OpenAI, Google, Microsoft | Med | TypeScript MCP SDK, stdio transport |
| Tool: list_devices | Device discovery | Low | Wraps device management layer |
| Tool: get_screenshot | Core visual capability | Low | Returns base64 image |
| Tool: get_ui_tree | Core structural capability | Med | Returns filtered accessibility tree |
| Tool: tap (by index or coordinates) | Core interaction | Low | Wraps tap with index resolution |
| Tool: type_text | Core interaction | Low | Wraps text input |
| Tool: swipe | Core interaction | Low | Wraps swipe gesture |
| Tool: launch_app | App management | Low | Wraps app launch |
| Tool: terminate_app | App management | Low | Wraps app termination |
| Tool: press_button | Hardware key access | Low | Wraps key events |
| Tool: go_home | Navigation shortcut | Low | Wraps home press |
| Tool: open_url | Deep link / URL navigation | Low | Wraps URL intent |

### AiBridge CLI (PTY Wrapper)

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| PTY wrapper for terminal AI agents | Core architecture from MobAI reference; the mechanism enabling context injection | High | Go + creack/pty; raw mode terminal emulation with window resize |
| HTTP API for text injection (POST /inject) | How external systems push context into AI agent terminal | Med | JSON body with text + priority flag; returns queue position |
| Idle detection (regex-based) | Must know when AI agent is ready for input; MobAI uses 500ms pattern timeout | Med | Match "esc to interrupt" etc. against PTY output stream |
| Injection queue (FIFO with priority) | Multiple sources may inject; queue prevents races and dropped messages | Med | Max 100 items, priority flag bumps to front |
| Health/status endpoints (GET /health, GET /status) | Monitoring bridge state, uptime, queue depth | Low | JSON responses with bridge status |
| Support for Claude Code, Codex, Gemini CLI | The three major terminal AI coding agents | Low | Built-in regex patterns per agent for idle detection |
| Custom busy pattern flag (--busy-pattern) | Users may use other terminal AI tools beyond the big three | Low | CLI flag accepting regex string |

---

## Differentiators

Features that set OpenMob apart. Not expected by default, but create competitive advantage -- especially vs MobAI.

### Self-Hosted / No Limits (PRIMARY differentiator)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Zero quotas, unlimited usage | MobAI Free = 100 pts/day, Plus = $4.99/mo, Pro = $9.99/mo. OpenMob = free forever | Low (architecture) | Not code to build but a constraint to maintain: no license checks, no telemetry, no point system |
| Unlimited device connections | MobAI Free/Plus = 1 device. Pro = unlimited but $9.99/mo and 3 machines max | Low | Simply don't add device limits |
| Fully offline operation | MobAI requires internet for license validation (except 7-day Pro offline window) | Low | No external API calls, no license server, no phone-home |
| No cloud dependency | Everything runs on user's machine; no data leaves localhost | Low | Architecture decision enforced by localhost-only binding |

### Flutter Desktop Hub App

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Visual device management dashboard | MobAI has a closed-source desktop app. An open-source GUI for managing everything is unique in this space | High | Flutter Desktop; cross-platform (Win/Mac/Linux) |
| Live device screen preview | See connected device screens in the hub without needing a separate tool | Med | Periodic screenshot polling displayed in Flutter Image widget |
| Bridge lifecycle control (start/stop per device) | Visual toggle for which devices have active automation bridges | Med | Spawns/kills AiBridge + MCP processes per device |
| Connection status monitoring | Real-time visual feedback on device health, bridge state, queue depth | Med | Polls /health and /status endpoints, displays in UI |
| Multi-device overview | See all devices at a glance in grid/list; powerful when running multiple devices | Med | Device cards with status indicators |

### Advanced Gestures and Interaction

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Long press gesture | Context menus, drag initiation; mobile-mcp and MobAI both have it | Low | Extended duration tap via adb/simctl |
| Double tap gesture | Zoom, select word; both competitors support this | Low | Two rapid sequential taps |
| Screen orientation get/set | Test landscape vs portrait layouts | Low | ADB shell settings / simctl orientation; mobile-mcp has this |
| List installed apps | AI agent discovers what's installed before launching | Low | `adb shell pm list packages` / simctl listapps |
| Install app (APK on Android) | Deploy test builds programmatically without manual steps | Low | `adb install path.apk` |
| Install app (IPA on iOS Simulator) | Deploy simulator builds | Low | `xcrun simctl install` |
| Uninstall app | Clean up between test runs | Low | `adb uninstall` / `xcrun simctl uninstall` |
| Dismiss keyboard | Needed before tapping elements hidden behind keyboard | Low | ADB back key / dedicated keyboard dismiss |

### iOS Real Device Support

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| iOS real device automation via WebDriverAgent | Full iOS physical device support, not just simulator; mobile-mcp supports this | High | Requires WDA compilation, provisioning profile, Apple developer account |
| iOS real device screenshot | See real iPhone/iPad screens | High | Via WDA HTTP API on device port 8100 |
| iOS real device UI tree | Structured accessibility data from real hardware | High | Via WDA /source endpoint |

### Developer Experience

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Paranoid mode (inject without pressing Enter) | Safety: user reviews injected text before it's submitted to AI agent | Low | --paranoid flag on AiBridge CLI |
| Sync injection mode (?sync=true) | Block caller until text is actually delivered; useful for scripting and hub coordination | Low | Query parameter on POST /inject |
| Verbose logging mode | Debug bridge and device communication issues | Low | --verbose flag with detailed output |
| Single-binary distribution (AiBridge) | Go compiles to one binary; no runtime dependencies to install for the CLI component | Low | Standard Go build; cross-compile for Win/Mac/Linux |
| Configurable HTTP port and host | Run multiple bridges or avoid port conflicts | Low | --port and --host CLI flags |

---

## Anti-Features

Features to deliberately NOT build. These either contradict OpenMob's values, add unwarranted scope, or belong in a different product category.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **DSL scripting language (.mob format)** | MobAI's proprietary DSL is vendor lock-in. AI agents don't need a custom language -- they compose MCP tool calls directly. Building a parser, executor, conditional logic, and failure strategies is months of work for something AI agents bypass entirely. | Expose granular MCP tools. Let AI agents compose multi-step workflows through sequential tool calls. They are the orchestration layer. |
| **Built-in AI agent execution (run_agent)** | MobAI runs its own AI agent on-device for autonomous tasks. OpenMob's purpose is to be the BRIDGE, not the agent. The AI coding agent (Claude Code, Codex, Gemini) IS the agent. Building another agent creates confusion about who controls what. | Provide tools. Let the AI coding agent decide actions. OpenMob is infrastructure, not intelligence. |
| **Cloud/SaaS deployment** | Contradicts the core self-hosted differentiator. Cloud adds authentication, billing, infrastructure, latency, security concerns with remote device access. | Localhost only. No external calls. Self-hosted is the entire value prop. |
| **License validation / telemetry / analytics** | Contradicts "no limits" differentiator. Any phone-home behavior erodes trust with open-source users. Even opt-in telemetry creates suspicion. | No tracking. No analytics. No license checks. No point system. Period. |
| **AI test generation from natural language** | MobAI generates test scripts from natural language descriptions. This is a testing product feature, not an automation bridge feature. Massive scope creep requiring prompt engineering, test framework integration, assertion logic. | Focus on being the best bridge. Testing tools can be built ON TOP of OpenMob by downstream projects. |
| **App Store screenshot automation** | MobAI "Grow" feature for marketing teams. Niche use case that requires locale management, device size matrix, specific store format compliance. | Out of scope. Can be a community-built tool that uses OpenMob's API. |
| **Browser extension (ContextBox-like)** | MobAI has context-box for browser-based injection. Chrome extension APIs are a separate platform with review processes, manifest v3 migration, and ongoing maintenance burden. | CLI + MCP + Flutter Hub cover all injection paths. Browser extension is not needed for the core "AI controls device" workflow. |
| **Performance metrics (CPU/memory/FPS/battery monitoring)** | MobAI offers real-time profiling with metrics_start/metrics_stop. Useful for performance testing but not core to "AI sees and controls device." Each platform has entirely different profiling APIs, doubling implementation cost. | Defer to post-v1. AI agents can use `adb shell top` or Instruments directly if needed. Device logs provide some diagnostic capability. |
| **Webhooks system for device events** | MobAI supports webhooks (device:connected, bridge:started, etc.) with retry logic and custom headers. Adds HTTP client infrastructure, persistence, and delivery guarantees. Overkill when everything is local. | Hub polls status endpoints directly. Events are synchronous in a localhost-only architecture. |
| **OCR / Vision text detection** | MobAI has Apple Vision OCR on iOS. In 2026, LLMs have built-in vision capabilities. Claude, GPT-4, Gemini can all read screenshots directly. A separate OCR pipeline is redundant. | AI agents analyze screenshots themselves via their built-in vision. UI tree text covers structured data extraction. |
| **Parallel multi-device test orchestration** | MobAI Pro feature. Requires job scheduling, result aggregation, failure handling across devices. This is a test runner, not an automation bridge. | Support multiple devices connected simultaneously. Let the AI agent (or a test framework built on OpenMob) handle orchestration. |
| **GUI test recorder** | Record-and-replay tools produce brittle tests that break on layout changes. AI agents observe dynamically and adapt -- they ARE the recorder. | AI agents watch screenshots and UI trees in real-time. No recording needed. |
| **Device farm / remote device management** | Massively complex distributed infrastructure. Contradicts self-hosted simplicity. BrowserStack already does this. | Support only locally-connected devices (USB, WiFi, local emulators/simulators). |

---

## Feature Dependencies

```
Platform-Specific Device Layer:
  ADB (Android USB/WiFi/Emulator) ──┐
  simctl (iOS Simulator) ───────────┼──> Unified Device Abstraction
  WebDriverAgent (iOS Real Device) ─┘         │
                                              │
  Device Abstraction provides:                │
    - screenshot()                            │
    - getUiTree()                             │
    - tap(x, y)                               │
    - type(text)                              │
    - swipe(direction)                        │
    - launchApp(id)                           │
    - terminateApp(id)                        │
    - pressButton(key)                        │
    - openUrl(url)                            │
    - listApps()                              │
    - getDeviceInfo()                         │
                                              v
                              MCP Server (TypeScript)
                              Exposes tools via stdio transport
                              Consumes device abstraction
                                              │
                                              │ (AI client calls MCP tools,
                                              │  gets results including screenshots)
                                              │
PTY Wrapper (Go) ──> AiBridge CLI             │
  - creack/pty for terminal emulation         │
  - cobra for CLI framework                   │
  - Idle detection (regex on PTY output)      │
  - HTTP API (localhost:9999)                 │
    - POST /inject (queue text)               │
    - GET /health                             │
    - GET /status                             │
    - DELETE /queue                           │
                                              │
Flutter Desktop Hub ──────────────────────────┘
  Orchestrates everything:
  - Discovers devices (calls device layer)
  - Manages bridge processes (spawns AiBridge + MCP)
  - Shows device status (polls HTTP endpoints)
  - Optional: live screen preview (periodic screenshots)

Build Order (dependency chain):
  1. Device automation wrappers (ADB, simctl) -- no deps, pure shell commands
  2. MCP Server -- depends on #1 (calls device layer)
  3. AiBridge CLI -- independent of #1 and #2 (pure PTY + HTTP)
  4. Flutter Hub -- depends on #2 and #3 (orchestrates both)

Within device interaction (tool-level deps):
  tap_by_index ──> get_ui_tree (must have tree to resolve index)
  type_text ──> (assumes field is focused; focusing is AI's responsibility)
  all tools ──> list_devices (must select a target device first)
```

---

## Web Automation (Deferred -- Phase 3+)

Web automation for mobile browsers/WebViews is legitimate but warrants separate phasing due to high complexity.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| List browser tabs/WebViews | Discover web contexts on device | High | Chrome DevTools Protocol (Android), WebInspector protocol (iOS) |
| Navigate to URL in mobile browser | Direct browser control | Med | CDP command or WebInspector command |
| Get DOM tree from mobile browser | Structured web page content for AI | High | Full CDP session management |
| Click element by CSS selector | Web element interaction | High | CDP Runtime.evaluate with click |
| Type into element by CSS selector | Web form filling | High | CDP Runtime.evaluate with value set |
| Execute arbitrary JavaScript | Custom web automation scripting | High | CDP evaluation; security implications |

**Recommendation:** Defer web automation entirely. Native app automation is the core use case for AI coding agents building mobile apps. Web automation adds two protocol stacks (Chrome DevTools Protocol for Android, WebInspector for iOS), requires session management, and doubles the testing surface. Ship native automation first; add web if user demand justifies the cost.

---

## Device Log Streaming (Deferred -- Phase 2)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Stream Android logs (logcat) | AI agents can read runtime errors, crash logs, debug output | Med | `adb logcat` with filtering piped through SSE or stored in ring buffer |
| Stream iOS Simulator logs | Same debugging capability for iOS | Med | `xcrun simctl spawn log stream` |
| Filter logs by process/level/tag | Reduce noise; LLM context windows are finite | Med | Parse log format, apply filters before delivery |
| MCP tool: get_device_logs | Expose filtered logs to AI agent on demand | Med | Returns recent log lines matching filter criteria |

**Recommendation:** Strong Phase 2 candidate. Log streaming gives AI agents debugging superpowers that screenshots and UI trees alone cannot provide. When an app crashes or misbehaves, the AI agent can read the logcat/syslog output and diagnose the issue. Implementation is moderate (shell out to logcat/log stream, buffer recent lines, expose via MCP tool).

---

## MVP Recommendation

### Phase 1: Core Bridge (Table Stakes + Primary Differentiator)

Ship these to deliver the complete "AI agent sees and controls a mobile device" loop:

1. **AiBridge CLI** (Go) -- PTY wrapper + HTTP injection API + idle detection for Claude Code/Codex/Gemini CLI
2. **Android automation via ADB** -- screenshot, UI tree, tap (coordinates + index), type, swipe, launch/terminate app, press hardware keys, go home, open URL
3. **iOS Simulator automation via simctl** -- same feature set as Android (simctl supports all of these)
4. **MCP Server** (TypeScript) -- expose all device tools as MCP tools with stdio transport
5. **Flutter Hub (minimal)** -- device list, connection status, start/stop bridge per device

This delivers the full value loop: connect device, AI gets screenshot + UI tree, AI taps/types/swipes, repeat. No quotas. No limits. Self-hosted.

### Phase 2: Deepen and Polish

6. **iOS real device support** via WebDriverAgent (biggest complexity item; requires provisioning)
7. **Device log streaming** as MCP tools (logcat + syslog)
8. **App install/uninstall** via MCP tools
9. **Advanced gestures** -- long press, double tap, dismiss keyboard
10. **Hub enhancements** -- live device screen preview, multi-device grid, connection quality indicators
11. **Screen orientation** get/set

### Phase 3: Extended Platform (if demand)

12. Web automation (Chrome DevTools Protocol + WebInspector)
13. Port forwarding (host-to-device tunnels)
14. Location simulation (GPS spoofing)
15. Multi-agent orchestration (multiple AI agents, each with own bridge)

**Phase ordering rationale:**
- Phase 1 covers every table-stakes feature. It matches MobAI's free tier capabilities while removing all restrictions.
- Phase 2 adds the features that make OpenMob genuinely more capable than MobAI Free (real device iOS, logs, advanced gestures).
- Phase 3 covers niche/advanced features that only matter once the core is solid and adopted.

---

## Sources

- [MobAI Documentation](https://mobai.run/docs/) -- HTTP API reference with 40+ endpoints, DSL spec, web automation docs (HIGH confidence)
- [MobAI Homepage / Pricing](https://mobai.run/) -- Free/Plus/Pro tier comparison, feature limits (HIGH confidence)
- [MobAI AiBridge GitHub](https://github.com/MobAI-App/aibridge) -- Go PTY wrapper architecture, HTTP API design, idle detection patterns (HIGH confidence)
- [MobAI MCP Server GitHub](https://github.com/MobAI-App/mobai-mcp) -- 20+ MCP tool definitions, stdio transport (HIGH confidence)
- [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) -- Alternative open-source MCP server for mobile, 4.1k stars, Apache 2.0 (HIGH confidence)
- [DroidRun](https://github.com/droidrun/droidrun) -- Open-source Android agent framework, 3.8k+ stars, manager-executor pattern (MEDIUM confidence)
- [Appium MCP articles](https://medium.com/@anthonypdawson/appium-mcp-unlocks-new-methodologies-in-mobile-automation-791a56878285) -- Appium + MCP integration patterns (MEDIUM confidence)
- [Android Debug Bridge](https://developer.android.com/tools/adb) -- Official ADB documentation (HIGH confidence)
- [xcrun simctl reference](https://www.iosdev.recipes/simctl/) -- iOS Simulator CLI commands (HIGH confidence)
- [Appium WebDriverAgent](https://github.com/appium/WebDriverAgent) -- iOS real device automation via WDA (HIGH confidence)
