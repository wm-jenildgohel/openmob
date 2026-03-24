---
phase: 03-aibridge-cli
plan: 04
subsystem: cli
tags: [rust, clap, tokio, pty, signal-handling, cross-compilation, which]

requires:
  - phase: 03-aibridge-cli (plans 01-03)
    provides: PTY handler, ANSI stripping, busy detector, injection queue, bridge orchestrator, HTTP server with handlers
provides:
  - Full CLI wiring: parse args, detect tool, resolve agent, spawn bridge + HTTP server concurrently
  - Signal handling (SIGINT/SIGTERM) with graceful shutdown
  - Tool detection at startup with install guidance
  - Makefile for cross-compilation to 5 platform/arch combos
  - Terminal restore guard for crash safety
affects: [phase-04-flutter-hub, phase-05-qa-testing]

tech-stack:
  added: [which]
  patterns: [tokio::select! for concurrent subsystems, RAII guard for terminal restore, signal_handler async function with cfg(unix)]

key-files:
  created: [openmob_bridge/Makefile, openmob_bridge/.gitignore]
  modified: [openmob_bridge/src/main.rs, openmob_bridge/src/bridge.rs, openmob_bridge/Cargo.toml]

key-decisions:
  - "Top-level TerminalRestoreGuard as safety net separate from Bridge's internal RawModeGuard"
  - "signal_handler() as standalone async fn with cfg(unix) for SIGTERM support"
  - "Bridge::shutdown() public method for external cancel trigger from signal handler"

patterns-established:
  - "tokio::select! for running bridge + HTTP server + signal handler concurrently"
  - "RAII Drop guard pattern for terminal raw mode restoration"
  - "which crate for tool-in-PATH detection with user-friendly install guidance"

requirements-completed: [BRG-01, BRG-02, BRG-03, BRG-04, BRG-05, BRG-06, BRG-07, BRG-08, BRG-09, BRG-10]

duration: 4min
completed: 2026-03-24
---

# Phase 03 Plan 04: CLI Wiring Summary

**Full CLI assembly: tool detection, bridge+server concurrent startup via tokio::select!, signal handling, terminal restore guard, and Makefile with 5 cross-compile targets**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-24T12:33:37Z
- **Completed:** 2026-03-24T12:37:39Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Complete CLI wiring: main.rs parses args, detects tool in PATH, resolves agent pattern, creates bridge and HTTP server, runs them concurrently
- Tool detection at startup with which crate -- shows install guidance for claude/codex/gemini if not found
- Signal handling for SIGINT (all platforms) and SIGTERM (Unix) with graceful bridge shutdown
- Makefile with build, release, install, check, fmt, clean, and 5 cross-compile targets (linux/darwin amd64+arm64, windows amd64)

## Task Commits

Each task was committed atomically:

1. **Task 1: Full CLI wiring with signal handling and tool detection** - `01602e1` (feat)
2. **Task 2: Makefile for cross-compilation and prebuilt binaries** - `a884258` (feat)

## Files Created/Modified
- `openmob_bridge/src/main.rs` - Full CLI wiring: arg parsing, tool detection, bridge+server startup, signal handling, terminal restore
- `openmob_bridge/src/bridge.rs` - Added public shutdown() method for external cancel trigger
- `openmob_bridge/Cargo.toml` - Added which = "7" dependency
- `openmob_bridge/Makefile` - Cross-compilation targets for 5 platforms via cross tool
- `openmob_bridge/.gitignore` - Excludes /target and /dist directories

## Decisions Made
- Top-level TerminalRestoreGuard as safety net separate from Bridge's internal RawModeGuard -- double protection ensures terminal is never left in raw mode
- signal_handler() as standalone async fn with cfg(unix) for SIGTERM support, cfg(not(unix)) fallback for Windows
- Bridge::shutdown() public method allows main to trigger graceful shutdown from signal handler without exposing internal CancellationToken

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added Bridge::shutdown() public method**
- **Found during:** Task 1 (CLI wiring)
- **Issue:** Bridge had no public way to trigger shutdown from outside -- signal handler needed to cancel the bridge
- **Fix:** Added `pub fn shutdown(&self)` that calls `self.cancel.cancel()`
- **Files modified:** openmob_bridge/src/bridge.rs
- **Verification:** cargo check passes, shutdown integrated in main.rs signal handling
- **Committed in:** 01602e1 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 missing critical)
**Impact on plan:** Essential for signal handling to work. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- AiBridge CLI is fully functional: binary runs, wraps terminal commands via PTY, detects agents, starts HTTP API, handles signals
- Ready for Phase 04 (Flutter Hub) integration -- Hub can launch aibridge binary and communicate via HTTP API on port 9999
- Cross-compilation ready via `make cross-all` (requires `cargo install cross` and Docker)

---
*Phase: 03-aibridge-cli*
*Completed: 2026-03-24*
