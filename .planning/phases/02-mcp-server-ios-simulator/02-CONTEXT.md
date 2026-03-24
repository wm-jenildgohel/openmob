# Phase 2: MCP Server + iOS Simulator - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

AI agents in MCP-compatible clients (Cursor, Claude Desktop, Windsurf, VS Code) can control both Android devices and iOS Simulators through standardized MCP tools. The MCP server is a TypeScript/Node.js process using the official MCP SDK, communicating via stdio transport. It is stateless — all device operations route through the Hub's HTTP API on localhost:8686. iOS Simulator support adds xcrun simctl-based automation for screenshots, UI tree, and device interactions.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Key constraints:
- MCP SDK TypeScript (official @modelcontextprotocol/sdk)
- stdio transport (not Streamable HTTP)
- Stateless MCP server — Hub HTTP API is source of truth
- iOS Simulator via xcrun simctl (macOS only)
- Bind to 127.0.0.1 only for security
- Must expose: list_devices, get_screenshot, get_ui_tree, tap, type_text, swipe, launch_app, terminate_app, press_button, go_home, open_url

</decisions>

<code_context>
## Existing Code Insights

Phase 1 delivered:
- Flutter Hub with HTTP API on localhost:8686
- Endpoints: GET /health, GET /api/v1/devices, POST /api/v1/devices/:id/screenshot, etc.
- ADB service, DeviceManager, ScreenshotService, UiTreeService, ActionService
- All models: Device, UiNode, ActionResult

MCP server will be a SEPARATE Node.js project (openmob_mcp/) that calls the Hub HTTP API.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — discuss phase skipped. Refer to ROADMAP phase description and success criteria.

</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.

</deferred>
