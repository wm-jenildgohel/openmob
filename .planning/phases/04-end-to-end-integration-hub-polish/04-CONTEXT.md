# Phase 4: End-to-End Integration + Hub Polish - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Wire all three components (Hub, MCP Server, AiBridge) into a unified system. Hub manages process lifecycles (start/stop MCP and AiBridge), provides live device screen preview via periodic screenshot polling, and a scrollable log viewer for device/bridge logs. The full AI-sees-device-and-acts loop must work end-to-end.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped.

Key constraints:
- Use rxdart BehaviorSubject for all state (NEVER setState)
- Use rescolors always
- Use ui-ux-pro-max patterns for good responsive desktop UI
- Hub manages MCP server (Node.js process) and AiBridge (Rust binary) lifecycles via Process.start
- Live preview: periodic screenshot fetch from Hub API, display in Flutter Image widget
- Log viewer: capture stdout/stderr from managed processes, display in scrollable ListView
- Process management: spawn, monitor, kill child processes from Flutter
- System check screen: detect and report availability of ADB, Node.js, Rust/AiBridge binary, idb

</decisions>

<code_context>
## Existing Code Insights

Phase 1: Flutter Hub with HTTP API, device management, ADB services, basic UI
Phase 2: TypeScript MCP server (openmob_mcp/), iOS simulator support
Phase 3: Rust AiBridge CLI (openmob_bridge/)

Hub files to extend:
- lib/main.dart (add process management)
- lib/ui/screens/ (add new screens)
- lib/services/ (add ProcessManager service)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — discuss phase skipped.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
