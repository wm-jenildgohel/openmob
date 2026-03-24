# Project Research Summary

**Project:** OpenMob - AI-powered Mobile Device Automation Bridge
**Domain:** Developer tooling / Mobile automation / MCP infrastructure
**Researched:** 2026-03-24
**Confidence:** MEDIUM-HIGH

## Executive Summary

OpenMob is a three-component system that bridges AI coding agents (Claude Code, Codex CLI, Gemini CLI) to mobile devices. The architecture comprises a Go-based PTY wrapper (AiBridge CLI) that intercepts terminal I/O to inject device context into AI agents, a TypeScript MCP server that exposes device automation as standardized MCP tools, and a Flutter Desktop hub that serves as the central control plane managing device connections and exposing an HTTP API. This architecture directly mirrors MobAI's proven model but replaces proprietary components with open-source equivalents and removes all usage quotas, license checks, and cloud dependencies.

The recommended approach is to build the Flutter Hub's HTTP API and device management layer first, since every other component depends on it. The MCP server is a thin translation layer on top of the Hub API, and AiBridge CLI is fully independent (it wraps any terminal process, no device knowledge needed). Go 1.26 with creack/pty is the clear choice for PTY management, the official MCP TypeScript SDK v1.27.x with stdio transport is the only sensible MCP implementation, and Flutter 3.41.x with rxdart handles the desktop hub. All technology choices have HIGH confidence -- there are no genuine alternatives worth debating.

The primary risks are: PTY read/EOF race conditions in Go that cause hung sessions (must be addressed in the very first implementation with context-based lifecycle management), MCP security vulnerabilities from binding to 0.0.0.0 instead of 127.0.0.1 (hard-code localhost, no exceptions), regex-based idle detection breaking when AI agents update their terminal UI (make patterns configurable and strip ANSI codes), and the integration gap between three independently-developed components speaking different protocols (define HTTP API contracts before building anything, integrate continuously).

## Key Findings

### Recommended Stack

The stack is a polyglot three-component system. Each component uses the best-fit language for its domain. There are no significant technology decision risks -- every choice has strong community backing and active maintenance.

**Core technologies:**
- **Go 1.26 + creack/pty + cobra** (AiBridge CLI) -- single-binary PTY wrapper with HTTP API. Go's concurrency primitives and PTY support are unmatched for this use case.
- **Node.js 24 LTS + TypeScript 5.7 + @modelcontextprotocol/sdk 1.27.x + zod 4.3** (MCP Server) -- MCP SDK is TypeScript-first; no real alternative. Stdio transport for local use.
- **Flutter 3.41.x + Dart 3.11 + rxdart 0.28.x** (Desktop Hub) -- cross-platform desktop with reactive state management per project preference. HTTP API server for the control plane.
- **ADB + xcrun simctl** (Device Layer) -- standard platform tools for Android/iOS automation. No wrappers needed for v1.
- **sharp 0.34.x** (Screenshot Processing) -- high-perf image resizing before sending to LLMs. 4-5x faster than jimp.

**Critical version requirement:** Go 1.22+ needed for stdlib HTTP routing with method-based matching and path wildcards (eliminates need for chi/gin).

### Expected Features

**Must have (table stakes):**
- Device discovery and connection (ADB USB/WiFi/emulator + iOS Simulator)
- Screenshot capture and base64 encoding for LLM consumption
- UI accessibility tree extraction with element indices
- Core interaction: tap (coordinates + element index), type, swipe, press hardware keys
- App lifecycle: launch, terminate, open URL, go home
- MCP server exposing all device tools via stdio transport
- AiBridge CLI: PTY wrapper + HTTP injection API + idle detection for Claude Code/Codex/Gemini CLI
- Health/status HTTP endpoints

**Should have (competitive differentiators):**
- Zero quotas / unlimited usage / fully offline (primary differentiator vs MobAI's paid tiers)
- Flutter Desktop hub with visual device management
- Live device screen preview in hub
- Advanced gestures: long press, double tap, dismiss keyboard
- App install/uninstall via MCP tools
- Device log streaming (logcat / syslog) as MCP tools
- Paranoid mode (review injection before sending)

**Defer (v2+):**
- iOS real device automation (WebDriverAgent -- completely different toolchain from simulator)
- Web automation (Chrome DevTools Protocol + WebInspector -- two new protocol stacks)
- Performance metrics (CPU/memory/FPS/battery)
- DSL scripting language (anti-feature: AI agents compose tool calls directly)
- Built-in AI agent execution (anti-feature: OpenMob is bridge, not agent)
- Cloud/SaaS deployment (anti-feature: contradicts self-hosted value prop)

### Architecture Approach

Three-process architecture on localhost. The Flutter Hub is the central nervous system: it owns the HTTP API (localhost:8686), device connections, and process lifecycle management. The MCP server is stateless -- it translates MCP tool calls into Hub HTTP requests. AiBridge CLI is independent -- it wraps any terminal process via PTY, exposes injection at localhost:9999, and knows nothing about devices. Communication is HTTP REST between components, stdio between MCP client and server, and PTY between AiBridge and AI agent. All data flows through in-memory HTTP responses (base64 for binary); no filesystem temp files in the hot path.

**Major components:**
1. **Flutter Desktop Hub** (localhost:8686) -- Device discovery, connection management, screenshot/UI tree capture, action execution, AiBridge process lifecycle, user GUI
2. **MCP Server** (stdio transport) -- Stateless translation layer: MCP tool calls to Hub HTTP calls. ~15 tools across device management, screen inspection, UI actions, app control
3. **AiBridge CLI** (localhost:9999) -- Agent-agnostic PTY wrapper with HTTP injection queue, regex-based idle detection, and support for Claude Code/Codex/Gemini CLI

**Key patterns:**
- Hub as single source of truth for device state (MCP server never caches)
- Command-query separation (GET for screenshots/trees, POST for actions)
- Async bridge startup with status polling for long operations
- Screenshot pipeline optimization (exec-out, no disk I/O, resize before encode)
- Graceful platform degradation (Android-only on Windows/Linux, full support on macOS)

### Critical Pitfalls

1. **PTY read/EOF race conditions** -- Go PTY I/O is inherently racy; `ptmx.Read()` blocks indefinitely or returns unexpected EOF. Use `context.WithCancel`, set read deadlines, test on both Linux and macOS from day one. Must solve in first implementation.

2. **MCP server binding to 0.0.0.0** -- CVE-2025-49596 (CVSS 9.4). Hard-code `127.0.0.1`, add startup verification that non-loopback connections fail. Zero tolerance.

3. **Idle detection regex fragility** -- AI agents update their terminal UI frequently, breaking pattern matching silently. Strip ALL ANSI codes before matching, make patterns configurable per-agent, implement fallback heuristics, include pattern test mode.

4. **ADB screenshot/UI dump performance** -- screencap takes 300-500ms, uiautomator dump takes 1-3s and fails during animations. Use `adb exec-out` (not `adb shell`), resize before encoding, cache with short TTL. Flutter apps are especially problematic (UIAutomator cannot dump Flutter view hierarchies).

5. **Integration gap between three components** -- The single biggest meta-risk. Define HTTP API contracts (OpenAPI schema) BEFORE building components. Build minimal end-to-end integration test early. Integrate continuously, never "build all, integrate later."

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Flutter Hub Core + Android Device Layer
**Rationale:** The Hub is the foundation -- every other component calls it. Android via ADB is the simplest device platform with the best tooling. Building these together delivers a testable HTTP API immediately (curl/Postman).
**Delivers:** HTTP API server at localhost:8686, Android device discovery, screenshot capture, UI tree extraction, tap/swipe/type actions, app launch/terminate, basic Flutter desktop UI with device list and status.
**Addresses:** All Android table-stakes features from FEATURES.md. Device management, screen capture, UI inspection, device interaction, app control.
**Avoids:** ADB screenshot perf pitfall (#4) by using `exec-out` from the start. Platform degradation pitfall (#5 partial) by building abstracted DeviceDriver interface even though only Android is implemented.
**Stack:** Flutter 3.41.x, Dart 3.11, rxdart 0.28.x, ADB platform-tools.

### Phase 2: MCP Server + iOS Simulator Support
**Rationale:** MCP server has the highest user-visible impact after the Hub API exists. With Hub + MCP, users can control Android devices from Cursor/Claude Desktop -- a demo-able milestone. Adding iOS Simulator support here expands platform coverage before AiBridge complexity.
**Delivers:** TypeScript MCP server with stdio transport exposing ~15 tools. iOS Simulator automation via xcrun simctl (screenshot, UI tree, tap, type, swipe, app lifecycle). Full AI-agent-controls-device loop via MCP.
**Addresses:** MCP integration table stakes from FEATURES.md. iOS Simulator connectivity. Tool: list_devices through Tool: open_url.
**Avoids:** 0.0.0.0 binding pitfall (#2) -- hard-code 127.0.0.1, startup verification. Transport lock-in (#7) -- stdio primary, never SSE. Tool poisoning (#8) -- input validation and logging from start.
**Stack:** Node.js 24 LTS, TypeScript 5.7+, @modelcontextprotocol/sdk 1.27.x, zod 4.3.x, execa 9.6.x.

### Phase 3: AiBridge CLI (PTY Wrapper)
**Rationale:** Fully independent of device automation -- can be built and tested in parallel with Phase 2. Wraps any terminal command, not just AI agents. Completing this enables the full context injection flow.
**Delivers:** Go binary with PTY wrapping, HTTP injection API (POST /inject, GET /health, GET /status, DELETE /queue), idle detection for Claude Code/Codex/Gemini CLI, configurable busy patterns, priority queue.
**Addresses:** AiBridge CLI table stakes from FEATURES.md. Paranoid mode and sync injection differentiators.
**Avoids:** PTY race conditions (#1) -- context-based lifecycle, read deadlines, cross-platform CI. Goroutine leaks (#6) -- process group cleanup, goleak testing. Idle detection fragility (#3) -- ANSI stripping, configurable patterns, fallback heuristics. ANSI pollution (#11) -- plain text injection. HTTP API future-proofing (#14) -- design for MCP integration upfront.
**Stack:** Go 1.26, creack/pty v1.1.24, cobra v2.3.0, viper, net/http stdlib, slog.

### Phase 4: End-to-End Integration + Hub Polish
**Rationale:** All three components exist. This phase wires them together and polishes the user experience. The integration gap meta-pitfall demands dedicated attention.
**Delivers:** Full automation loop: AI agent sees device, acts on device via context injection. Hub manages AiBridge + MCP process lifecycle. Live device screen preview. Multi-device grid view. Connection quality indicators.
**Addresses:** Hub differentiators from FEATURES.md: live preview, bridge lifecycle control, multi-device overview. Integration flow from ARCHITECTURE.md.
**Avoids:** Integration gap meta-pitfall -- dedicated phase for integration testing. Windows cmd.exe flash (#9) -- native plugin with CREATE_NO_WINDOW. Multi-window perf (#12) -- single-window navigation.

### Phase 5: Advanced Features + iOS Physical Devices
**Rationale:** Core is solid and adopted. Now deepen capabilities: device logs give AI agents debugging superpowers, advanced gestures cover edge cases, iOS physical devices expand addressable market.
**Delivers:** Device log streaming (logcat + syslog) as MCP tools. App install/uninstall. Long press, double tap, dismiss keyboard. Screen orientation. iOS real device automation via WebDriverAgent/idb (macOS only).
**Addresses:** Phase 2 features from FEATURES.md MVP recommendation. iOS real device differentiator.
**Avoids:** iOS simulator vs physical gap (#5) -- DeviceDriver abstraction already in place from Phase 1. Xcode version coupling (#13) -- version detection and multi-version CI.

### Phase Ordering Rationale

- Hub first because it is the dependency root. MCP server and AiBridge both call the Hub. Cannot test anything without the device API.
- MCP server before AiBridge because it delivers user-visible value faster. Once Hub + MCP work, the product is usable from Cursor/Claude Desktop.
- AiBridge can parallel with Phase 2 since it has zero device dependencies. However, sequencing it as Phase 3 allows the team to focus.
- Integration as a dedicated phase because the meta-pitfall research strongly warns against "build all, integrate later." Three components, three languages, two protocols.
- Advanced features last because they are additive, not foundational. The core loop (AI sees device, AI controls device) works without logs, advanced gestures, or physical iOS devices.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 1:** Flutter Desktop HTTP server approach needs investigation -- `shelf` vs `dart_frog` vs raw `dart:io HttpServer` for the Hub's REST API.
- **Phase 3:** PTY management on macOS vs Linux has documented behavioral differences. Need cross-platform testing strategy research.
- **Phase 5:** iOS physical device automation via WebDriverAgent requires signing/provisioning research. Facebook idb vs raw xcrun devicectl capabilities comparison needed.

Phases with standard patterns (skip research-phase):
- **Phase 2:** MCP server implementation is thoroughly documented by the official SDK. Stdio transport is straightforward. xcrun simctl is well-documented.
- **Phase 4:** Integration is testing/wiring, not new technology. Patterns are established by the architecture.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Every technology choice has strong community backing, active maintenance, and no serious alternatives. Version-specific choices verified against release timelines. |
| Features | HIGH | Competitor analysis covered 4 tools (MobAI, mobile-mcp, DroidRun, Appium MCP). Table stakes are clear. Anti-features are well-reasoned. |
| Architecture | MEDIUM-HIGH | Three-component pattern mirrors proven MobAI architecture. Hub-as-control-plane is sound. iOS simulator automation via simctl less documented than Android/ADB. |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls backed by CVEs, GitHub issues, and multiple independent sources. iOS physical device pitfalls are less certain -- depends on Xcode version and evolving Apple tooling. |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **Flutter Desktop HTTP server performance at scale:** Research did not benchmark how many concurrent requests `dart:io HttpServer` can handle when managing 5-10 devices. May need shelf/dart_frog or isolates for concurrent device operations.
- **iOS Simulator tap/swipe mechanism:** `xcrun simctl` has limited input simulation compared to ADB's `input` command. The exact approach for coordinate-based taps on iOS Simulator (simctl vs idb vs AppleScript) needs validation during Phase 2 implementation.
- **Flutter app UI tree extraction:** UIAutomator cannot dump Flutter view hierarchies (flutter/flutter#106327). For Flutter-built apps, an alternative approach (Flutter debug protocol / Dart VM service) may be needed. This is a known gap that affects a significant portion of the target audience.
- **Screenshot caching strategy:** Architecture recommends hash-based cache to avoid redundant captures, but the hashing overhead vs recapture overhead tradeoff needs benchmarking.
- **MCP SDK v2 migration path:** v2 is anticipated but not stable. Need to monitor and plan migration from v1.27.x when v2 stabilizes.

## Sources

### Primary (HIGH confidence)
- [MobAI AiBridge GitHub](https://github.com/MobAI-App/aibridge) -- PTY wrapper architecture, HTTP API design, idle detection patterns
- [MobAI MCP Server GitHub](https://github.com/MobAI-App/mobai-mcp) -- MCP tool definitions, stdio transport
- [MobAI Documentation](https://mobai.run/docs/) -- HTTP API reference, DSL spec, pricing/limits
- [MCP TypeScript SDK](https://github.com/modelcontextprotocol/typescript-sdk) -- v1.27.1 official SDK
- [MCP Transport Specification](https://modelcontextprotocol.io/specification/2025-03-26/basic/transports) -- stdio vs Streamable HTTP
- [Android Debug Bridge](https://developer.android.com/tools/adb) -- official ADB documentation
- [Go 1.26 Release](https://go.dev/blog/go1.26) -- language/runtime features
- [Flutter 3.41 Release](https://blog.flutter.dev/whats-new-in-flutter-3-41-302ec140e632) -- desktop improvements

### Secondary (MEDIUM confidence)
- [mobile-next/mobile-mcp](https://github.com/mobile-next/mobile-mcp) -- alternative open-source MCP for mobile, 4.1k stars
- [DroidRun](https://github.com/droidrun/droidrun) -- Android agent framework, 3.8k stars
- [facebook/idb](https://github.com/facebook/idb) -- iOS Development Bridge
- [CVE-2025-49596 / NeighborJack](https://virtualizationreview.com/articles/2025/06/25/mcp-servers-hit-by-neighborjack-vulnerability-and-more.aspx) -- MCP localhost security
- [creack/pty Issues #114, #167](https://github.com/creack/pty) -- PTY race conditions
- [Go Issue #60481](https://github.com/golang/go/issues/60481) -- goroutine-friendly process waiting

### Tertiary (needs validation)
- Flutter Desktop multi-window performance characteristics (issue #168376 -- may improve in future Flutter releases)
- iOS `xcrun simctl` input simulation capabilities (sparse official documentation)
- ADB parallel command limits (~5 concurrent, anecdotal)

---
*Research completed: 2026-03-24*
*Ready for roadmap: yes*
