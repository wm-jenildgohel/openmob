# Phase 5: QA & Testing - Context

**Gathered:** 2026-03-25
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Users can define, execute, and review test scenarios on devices using AI agents and the Hub. Includes: MCP run_test tool for AI-driven testing, test script editor/runner in Hub, Flutter test integration (flutter test / flutter drive), and test results dashboard with pass/fail, screenshots on failure, and execution time.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — discuss phase was skipped.

Key constraints:
- Use rxdart BehaviorSubject for all state
- Use rescolors always
- No unnecessary docs
- MCP run_test tool: execute a sequence of device actions with assertions, return structured results
- Test scripts: JSON format defining steps (action + expected state assertions)
- Flutter test runner: spawn `flutter test` or `flutter drive` as child process, capture output
- Results dashboard: show pass/fail count, individual test details, failure screenshots, timing

</decisions>

<code_context>
## Existing Code Insights

All infrastructure is in place from Phases 1-4:
- Hub HTTP API with all device endpoints
- MCP server with 11 tools (need to add run_test as #12)
- ProcessManager for spawning/managing processes
- LogService for capturing process output
- DashboardShell with sidebar navigation
- DeviceManager, ScreenshotService, ActionService for device operations

</code_context>

<specifics>
## Specific Ideas

No specific requirements — discuss phase skipped.

</specifics>

<deferred>
## Deferred Ideas

None.

</deferred>
