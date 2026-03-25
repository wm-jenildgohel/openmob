# Roadmap: OpenMob

## Overview

OpenMob is built bottom-up from its dependency root: the Flutter Hub owns the device layer and HTTP API that every other component calls. Phase 1 delivers the Hub with Android device automation (the simplest, best-tooled platform). Phase 2 adds the MCP server and iOS Simulator support, completing the AI-agent-controls-device loop via Cursor/Claude Desktop. Phase 3 builds the independent AiBridge CLI for terminal AI agent wrapping and context injection. Phase 4 wires all three components together with full Hub UI polish and process lifecycle management. Phase 5 layers on QA/testing capabilities that depend on the integrated system. Every phase enforces the self-hosted, zero-quota, localhost-only constraints.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Hub Core + Android Device Layer** - Flutter Desktop hub with HTTP API, Android device discovery/automation, screenshot capture, UI tree extraction, and core device interactions
- [ ] **Phase 2: MCP Server + iOS Simulator** - TypeScript MCP server exposing all device tools via stdio, plus iOS Simulator automation via xcrun simctl
- [ ] **Phase 3: AiBridge CLI** - Rust PTY wrapper with HTTP injection API (axum), idle detection for Claude Code/Codex/Gemini CLI, and priority queue
- [ ] **Phase 4: End-to-End Integration + Hub Polish** - Wire all three components together, Hub manages process lifecycles, live device preview, full desktop UI
- [ ] **Phase 5: QA & Testing** - AI-driven test execution, test script management, Flutter test integration, and test result visualization in Hub

## Phase Details

### Phase 1: Hub Core + Android Device Layer
**Goal**: Users can discover, connect to, and control Android devices through the Hub's HTTP API and basic desktop UI
**Depends on**: Nothing (first phase)
**Requirements**: DEV-01, DEV-02, DEV-03, DEV-04, DEV-06, DEV-07, UI-01, UI-02, UI-04, UI-05, ACT-01, ACT-02, ACT-03, ACT-04, ACT-05, ACT-06, ACT-07, ACT-08, ACT-09, ACT-10, HUB-01, HUB-06, HUB-07, FREE-01, FREE-02, FREE-03, FREE-04
**Success Criteria** (what must be TRUE):
  1. User can run the Flutter Desktop Hub on Windows, macOS, or Linux and see a list of connected Android devices with model, OS version, and screen size
  2. User can connect to an Android device via USB, WiFi ADB, or emulator and the Hub shows real-time connection status
  3. User can capture a screenshot from any connected Android device and receive it as base64 PNG via the Hub's HTTP API
  4. User can extract a filtered UI accessibility tree with stable element indices from any connected Android device
  5. User can perform tap (by coordinate or element index), swipe, type text, press keys, launch/terminate apps, open URLs, and advanced gestures on any connected Android device via the HTTP API
**Plans**: 4 plans
Plans:
- [x] 01-01-PLAN.md -- Flutter project scaffold, models, constants, ADB service, HTTP server skeleton
- [x] 01-02-PLAN.md -- DeviceManager, ScreenshotService, UiTreeService
- [x] 01-03-PLAN.md -- ActionService, all HTTP API route handlers, wiring
- [x] 01-04-PLAN.md -- Desktop UI (home screen, device detail, device card, connection badge)
**UI hint**: yes

### Phase 2: MCP Server + iOS Simulator
**Goal**: AI agents in MCP-compatible clients can control both Android devices and iOS Simulators through standardized MCP tools
**Depends on**: Phase 1
**Requirements**: DEV-05, UI-03, MCP-01, MCP-02, MCP-03, MCP-04, MCP-05, MCP-06, MCP-07, MCP-08, MCP-09, MCP-10, MCP-11, MCP-12
**Success Criteria** (what must be TRUE):
  1. User can configure the MCP server in Cursor, Claude Desktop, Windsurf, or VS Code and see device tools available via stdio transport
  2. AI agent can list connected devices, capture screenshots, read UI trees, and perform all device interactions through MCP tool calls
  3. User can connect to iOS Simulators on macOS and perform screenshot capture, UI tree extraction, and device interactions via the same MCP tools
  4. All MCP tool calls route through the Hub HTTP API (MCP server is stateless, Hub is single source of truth)
**Plans**: 2 plans
Plans:
- [x] 02-01-PLAN.md -- iOS Simulator support in Hub (SimctlService, IdbService, platform-aware routing)
- [x] 02-02-PLAN.md -- TypeScript MCP server with all 11 device tools via stdio transport

### Phase 3: AiBridge CLI
**Goal**: Users can wrap any terminal AI agent with AiBridge to enable automatic context injection when the agent is idle
**Depends on**: Nothing (independent of Phase 1-2, but sequenced after for focus)
**Requirements**: BRG-01, BRG-02, BRG-03, BRG-04, BRG-05, BRG-06, BRG-07, BRG-08, BRG-09, BRG-10
**Success Criteria** (what must be TRUE):
  1. User can run `aibridge -- claude` (or codex/gemini) and interact with the AI agent normally through the PTY layer
  2. User can POST text to localhost:9999/inject and see it delivered to the AI agent when idle (or immediately in non-paranoid mode)
  3. User can check agent status via GET /health and GET /status, and manage the injection queue via DELETE /queue
  4. AiBridge correctly detects idle state for Claude Code, Codex CLI, and Gemini CLI using built-in regex patterns, with support for custom --busy-pattern
  5. AiBridge binds to 127.0.0.1 only, supports --paranoid mode (review before submit), and handles synchronous injection with configurable --timeout
**Plans**: 4 plans
Plans:
- [x] 03-01-PLAN.md -- Rust Cargo scaffold, portable-pty PTY module, ANSI stripping, agent patterns, clap CLI
- [x] 03-02-PLAN.md -- BusyDetector, InjectionQueue, Bridge orchestrator with tokio tasks
- [x] 03-03-PLAN.md -- Axum HTTP server with all 5 API endpoints (health, status, inject, queue clear)
- [x] 03-04-PLAN.md -- CLI wiring, tool detection, Makefile for cross-compilation

### Phase 4: End-to-End Integration + Hub Polish
**Goal**: All three components work together as a unified system -- the Hub manages MCP server and AiBridge lifecycles, and the full AI-sees-device-and-acts loop works end-to-end
**Depends on**: Phase 2, Phase 3
**Requirements**: HUB-02, HUB-03, HUB-04, HUB-05
**Success Criteria** (what must be TRUE):
  1. User can start/stop the MCP server and AiBridge processes directly from the Hub UI
  2. User can see a live screen preview for any connected device in the Hub (periodic screenshot polling)
  3. User can view device and bridge logs in a scrollable log viewer within the Hub
  4. The full loop works: AI agent (via AiBridge) receives device context (via MCP), decides on actions, executes them on device, and sees updated state -- all orchestrated through the Hub
**Plans**: 2 plans
Plans:
- [ ] 04-01-PLAN.md -- ProcessManager, LogService, SystemCheckService, models, ResColors update, main.dart wiring
- [ ] 04-02-PLAN.md -- Desktop UI overhaul: DashboardShell, sidebar, process controls, live preview, log viewer, system check screen
**UI hint**: yes

### Phase 5: QA & Testing
**Goal**: Users can define, execute, and review test scenarios on devices using AI agents and the Hub
**Depends on**: Phase 4
**Requirements**: MCP-13, QA-01, QA-02, QA-03, QA-04
**Success Criteria** (what must be TRUE):
  1. AI agent can execute test scenarios on a device via the MCP run_test tool and receive structured pass/fail results
  2. User can define test scripts (sequence of actions + assertions) in the Hub and trigger them
  3. User can run Flutter tests (flutter test / flutter drive) from the Hub
  4. Test results are displayed in the Hub with pass/fail status, failure screenshots, and execution time
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Hub Core + Android Device Layer | 4/4 | Complete | - |
| 2. MCP Server + iOS Simulator | 2/2 | Complete | - |
| 3. AiBridge CLI | 4/4 | Complete |  |
| 4. End-to-End Integration + Hub Polish | 0/2 | Planning complete | - |
| 5. QA & Testing | 0/TBD | Not started | - |
