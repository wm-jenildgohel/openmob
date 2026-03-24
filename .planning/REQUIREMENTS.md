# Requirements

**Project:** OpenMob
**Version:** v1
**Created:** 2026-03-24

---

## v1 Requirements

### Device Management

- [x] **DEV-01**: User can list all connected Android devices (USB, WiFi, emulator) with model, OS version, and screen size
- [x] **DEV-02**: User can connect to Android devices via USB using ADB
- [x] **DEV-03**: User can connect to Android devices via WiFi ADB (adb tcpip + adb connect)
- [x] **DEV-04**: User can connect to Android emulators (auto-detected via ADB)
- [ ] **DEV-05**: User can connect to iOS simulators via xcrun simctl (macOS only)
- [x] **DEV-06**: User can retrieve device metadata (model, OS, screen resolution, battery) for AI context
- [x] **DEV-07**: User can start and stop device automation bridge per device

### Screen Capture & UI Inspection

- [x] **UI-01**: User can capture a screenshot from any connected device and receive it as base64-encoded PNG
- [x] **UI-02**: User can extract the UI accessibility tree from Android devices (uiautomator dump)
- [ ] **UI-03**: User can extract the UI accessibility tree from iOS simulators (simctl accessibility)
- [x] **UI-04**: Each element in the UI tree has a stable index number for AI reference (e.g., "tap element #3")
- [x] **UI-05**: User can filter the UI tree by text regex, bounds, and visibility to reduce LLM context noise

### Device Interaction

- [x] **ACT-01**: User can tap at specific x,y coordinates on any connected device
- [x] **ACT-02**: User can tap a UI element by its index number (resolves to center of element bounds)
- [x] **ACT-03**: User can type text into the currently focused input field
- [x] **ACT-04**: User can perform swipe gestures (up, down, left, right) with configurable distance and duration
- [x] **ACT-05**: User can press hardware/soft keys (Home, Back, Enter, Volume Up/Down, Power)
- [x] **ACT-06**: User can navigate to home screen with a single command
- [x] **ACT-07**: User can launch any app by package name (Android) or bundle ID (iOS)
- [x] **ACT-08**: User can terminate/kill a running app
- [x] **ACT-09**: User can open a URL or deep link on the device
- [x] **ACT-10**: User can perform any interaction that is humanly possible on the device (long press, pinch, multi-touch)

### MCP Server

- [ ] **MCP-01**: MCP server exposes all device tools via stdio transport (compatible with Cursor, Claude Desktop, Windsurf, VS Code)
- [ ] **MCP-02**: Tool: list_devices — returns connected devices with metadata
- [ ] **MCP-03**: Tool: get_screenshot — captures and returns base64 screenshot for specified device
- [ ] **MCP-04**: Tool: get_ui_tree — returns filtered accessibility tree with element indices
- [ ] **MCP-05**: Tool: tap — tap by coordinates or element index
- [ ] **MCP-06**: Tool: type_text — input text into focused field
- [ ] **MCP-07**: Tool: swipe — perform directional swipe gesture
- [ ] **MCP-08**: Tool: launch_app — start app by package/bundle ID
- [ ] **MCP-09**: Tool: terminate_app — kill running app
- [ ] **MCP-10**: Tool: press_button — press hardware/soft key
- [ ] **MCP-11**: Tool: go_home — navigate to home screen
- [ ] **MCP-12**: Tool: open_url — open URL/deep link on device
- [ ] **MCP-13**: Tool: run_test — execute a test scenario (unit, integration, or manual) and return results

### AiBridge CLI

- [ ] **BRG-01**: AiBridge wraps any terminal AI agent (Claude Code, Codex, Gemini CLI) with a PTY layer
- [ ] **BRG-02**: AiBridge exposes HTTP API on localhost with POST /inject for text injection
- [ ] **BRG-03**: AiBridge detects when the wrapped AI agent is idle via regex-based pattern matching
- [ ] **BRG-04**: AiBridge has built-in idle detection patterns for Claude Code, Codex CLI, and Gemini CLI
- [ ] **BRG-05**: AiBridge maintains an injection queue (FIFO) with priority support (max 100 items)
- [ ] **BRG-06**: AiBridge exposes GET /health and GET /status endpoints for monitoring
- [ ] **BRG-07**: AiBridge supports --paranoid mode (inject text without auto-submitting)
- [ ] **BRG-08**: AiBridge supports custom --busy-pattern flag for other AI tools
- [ ] **BRG-09**: AiBridge supports synchronous injection with configurable timeout (--timeout flag)
- [ ] **BRG-10**: AiBridge binds to 127.0.0.1 only (localhost security, no network exposure)

### QA & Testing

- [ ] **QA-01**: AI agent can use MCP tools to execute test scenarios on device and report pass/fail results
- [ ] **QA-02**: User can define test scripts (sequence of actions + assertions) and run them from the hub
- [ ] **QA-03**: User can run Flutter tests (flutter test / flutter drive) from the hub and view results
- [ ] **QA-04**: Test results are displayed in the hub with pass/fail status, screenshots on failure, and execution time

### Flutter Desktop Hub

- [x] **HUB-01**: Hub displays all connected devices with real-time connection status (connected/disconnected/bridged)
- [ ] **HUB-02**: Hub shows live screen preview for any connected device (periodic screenshot polling)
- [ ] **HUB-03**: Hub provides start/stop bridge controls per device
- [ ] **HUB-04**: Hub shows device/bridge logs in a scrollable log viewer
- [ ] **HUB-05**: Hub manages MCP server and AiBridge process lifecycle (start/stop/restart)
- [x] **HUB-06**: Hub runs entirely locally with zero cloud dependency
- [x] **HUB-07**: Hub works on Windows, macOS, and Linux

### Self-Hosted & Free

- [x] **FREE-01**: No usage quotas, no daily point limits, no device limits
- [x] **FREE-02**: Fully offline operation — no license validation, no telemetry, no phone-home
- [x] **FREE-03**: All components bind to localhost only by default (security)
- [x] **FREE-04**: MIT licensed, fully open source

---

## v2 Requirements (Deferred)

- iOS physical device automation (requires WebDriverAgent + Xcode signing)
- Web automation for mobile browsers and WebViews (Chrome DevProtocol + WebInspector)
- Browser extension (ContextBox-like element capture)
- MJPEG streaming for real-time screen mirroring
- Device log streaming (logcat/os_log) for AI debugging
- Multi-device parallel testing
- Plugin/extension architecture for custom AI tool integrations

## Out of Scope

- Cloud/SaaS deployment — contradicts self-hosted core value
- MobAI-style DSL scripting (.mob files) — proprietary format, adds massive scope
- Built-in AI agent (MobAI's run_agent) — AI agents are external, we're the bridge
- App Store screenshot automation — growth feature, not core
- Telemetry or analytics — contradicts privacy-first stance
- User accounts or authentication — local tool, no users to authenticate
- Payment/subscription system — free forever

---

## Traceability

*Updated by roadmap creation*

| REQ-ID | Phase | Status |
|--------|-------|--------|
| DEV-01 | Phase 1 | Complete |
| DEV-02 | Phase 1 | Complete |
| DEV-03 | Phase 1 | Complete |
| DEV-04 | Phase 1 | Complete |
| DEV-05 | Phase 2 | Pending |
| DEV-06 | Phase 1 | Complete |
| DEV-07 | Phase 1 | Complete |
| UI-01 | Phase 1 | Complete |
| UI-02 | Phase 1 | Complete |
| UI-03 | Phase 2 | Pending |
| UI-04 | Phase 1 | Complete |
| UI-05 | Phase 1 | Complete |
| ACT-01 | Phase 1 | Complete |
| ACT-02 | Phase 1 | Complete |
| ACT-03 | Phase 1 | Complete |
| ACT-04 | Phase 1 | Complete |
| ACT-05 | Phase 1 | Complete |
| ACT-06 | Phase 1 | Complete |
| ACT-07 | Phase 1 | Complete |
| ACT-08 | Phase 1 | Complete |
| ACT-09 | Phase 1 | Complete |
| ACT-10 | Phase 1 | Complete |
| MCP-01 | Phase 2 | Pending |
| MCP-02 | Phase 2 | Pending |
| MCP-03 | Phase 2 | Pending |
| MCP-04 | Phase 2 | Pending |
| MCP-05 | Phase 2 | Pending |
| MCP-06 | Phase 2 | Pending |
| MCP-07 | Phase 2 | Pending |
| MCP-08 | Phase 2 | Pending |
| MCP-09 | Phase 2 | Pending |
| MCP-10 | Phase 2 | Pending |
| MCP-11 | Phase 2 | Pending |
| MCP-12 | Phase 2 | Pending |
| MCP-13 | Phase 5 | Pending |
| BRG-01 | Phase 3 | Pending |
| BRG-02 | Phase 3 | Pending |
| BRG-03 | Phase 3 | Pending |
| BRG-04 | Phase 3 | Pending |
| BRG-05 | Phase 3 | Pending |
| BRG-06 | Phase 3 | Pending |
| BRG-07 | Phase 3 | Pending |
| BRG-08 | Phase 3 | Pending |
| BRG-09 | Phase 3 | Pending |
| BRG-10 | Phase 3 | Pending |
| QA-01 | Phase 5 | Pending |
| QA-02 | Phase 5 | Pending |
| QA-03 | Phase 5 | Pending |
| QA-04 | Phase 5 | Pending |
| HUB-01 | Phase 1 | Complete |
| HUB-02 | Phase 4 | Pending |
| HUB-03 | Phase 4 | Pending |
| HUB-04 | Phase 4 | Pending |
| HUB-05 | Phase 4 | Pending |
| HUB-06 | Phase 1 | Complete |
| HUB-07 | Phase 1 | Complete |
| FREE-01 | Phase 1 | Complete |
| FREE-02 | Phase 1 | Complete |
| FREE-03 | Phase 1 | Complete |
| FREE-04 | Phase 1 | Complete |

---
*Last updated: 2026-03-24 after roadmap creation*
