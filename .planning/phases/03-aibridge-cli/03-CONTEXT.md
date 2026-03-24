# Phase 3: AiBridge CLI - Context

**Gathered:** 2026-03-24
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Go CLI tool that wraps terminal AI coding agents (Claude Code, Codex, Gemini CLI) with a PTY layer and exposes an HTTP API for context injection. The bridge detects when the agent is idle via regex patterns, then delivers queued text. Supports paranoid mode (inject without auto-submit), synchronous injection with timeout, and custom busy patterns.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped per user setting.

Key constraints:
- Go 1.22+ with creack/pty for PTY management
- cobra CLI framework for command structure
- stdlib net/http for HTTP server (no third-party router needed)
- Bind to 127.0.0.1:9999 only
- ANSI escape code stripping before regex matching
- Built-in idle patterns for Claude Code, Codex CLI, Gemini CLI
- FIFO injection queue with priority support (max 100 items)
- Reference: github.com/MobAI-App/aibridge (MIT licensed)

</decisions>

<code_context>
## Existing Code Insights

This is a standalone Go project (openmob_bridge/) — completely independent from the Flutter Hub and MCP server. No existing code to build on.

</code_context>

<specifics>
## Specific Ideas

No specific requirements — discuss phase skipped.

</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.

</deferred>
