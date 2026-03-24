# Phase 1: Hub Core + Android Device Layer - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Users can discover, connect to, and control Android devices through the Hub's HTTP API and basic desktop UI. This phase delivers the Flutter Desktop Hub application with an embedded HTTP server, ADB-based Android device management (USB, WiFi, emulator), screenshot capture, UI accessibility tree extraction, and all device interaction primitives (tap, swipe, type, keys, launch/terminate apps, URLs, advanced gestures). The Hub runs on Windows, macOS, and Linux with zero cloud dependency.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Key constraints from PROJECT.md:
- Use rxdart instead of setState (per user preference)
- Flutter Desktop for cross-platform support
- ADB for all Android automation
- Localhost-only HTTP binding (127.0.0.1)
- No cloud dependency, no telemetry, no license validation
- MIT licensed

</decisions>

<code_context>
## Existing Code Insights

Codebase context will be gathered during plan-phase research. This is a greenfield project — no existing code.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — discuss phase skipped. Refer to ROADMAP phase description and success criteria.

</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.

</deferred>
