---
phase: 03-aibridge-cli
plan: 01
subsystem: cli
tags: [rust, portable-pty, clap, axum, tokio, ansi, regex, pty]

requires:
  - phase: none
    provides: standalone phase

provides:
  - Rust Cargo project (aibridge) with all dependencies
  - PtyHandler with spawn/read/write/inject_text/resize/kill API
  - ANSI escape stripping function (strip_ansi)
  - Built-in busy patterns for claude, codex, gemini agents
  - clap CLI skeleton with all flags (port, host, busy-pattern, timeout, verbose, paranoid, inject-delay)
  - Pattern resolution with custom override and auto-detect

affects: [03-02, 03-03, 03-04]

tech-stack:
  added: [portable-pty 0.8, clap 4, axum 0.8, tokio 1, strip-ansi-escapes 0.2, regex 1, serde 1, serde_json 1, uuid 1, anyhow 1]
  patterns: [clap derive-based CLI, portable-pty MasterPty + take_writer, OnceLock for static pattern storage]

key-files:
  created:
    - openmob_bridge/Cargo.toml
    - openmob_bridge/src/main.rs
    - openmob_bridge/src/pty_handler.rs
    - openmob_bridge/src/ansi.rs
    - openmob_bridge/src/patterns.rs
  modified: []

key-decisions:
  - "Rust edition 2021 (not 2024) for broader compatibility"
  - "take_writer() for PTY write handle (portable-pty 0.8 API)"
  - "OnceLock for static builtin_patterns storage in detect_agent"
  - "anyhow for error handling in PTY operations"

patterns-established:
  - "Module-per-concern: ansi.rs, patterns.rs, pty_handler.rs as separate modules"
  - "clap derive Parser for CLI args with trailing_var_arg for command capture"

requirements-completed: [BRG-01, BRG-04, BRG-08]

duration: 4min
completed: 2026-03-24
---

# Phase 3 Plan 01: Cargo Scaffold Summary

**Rust Cargo project with portable-pty PTY handler, ANSI stripping, 3 agent busy-patterns, and clap CLI skeleton**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-24T12:14:16Z
- **Completed:** 2026-03-24T12:18:25Z
- **Tasks:** 1
- **Files modified:** 6

## Accomplishments
- Compilable Rust project with 10 dependencies resolved
- PTY handler with full spawn/read/write/inject/resize/kill API surface
- ANSI escape stripping via strip-ansi-escapes crate
- Built-in busy patterns for claude ("thinking"), codex ("esc to interrupt"), gemini ("esc to cancel")
- Pattern resolution: custom --busy-pattern > auto-detect from command > default fallback
- CLI parses all 7 flags with sensible defaults (port 9999, host 127.0.0.1, timeout 300s, inject-delay 50ms)

## Task Commits

1. **Task 1: Cargo project scaffold with PTY and ANSI modules** - `b2cf32f` (feat)

## Files Created/Modified
- `openmob_bridge/Cargo.toml` - Project manifest with all 10 dependencies
- `openmob_bridge/src/main.rs` - clap CLI entry point with tokio async main
- `openmob_bridge/src/pty_handler.rs` - PtyHandler struct with portable-pty spawn and I/O
- `openmob_bridge/src/ansi.rs` - strip_ansi function for ANSI escape removal
- `openmob_bridge/src/patterns.rs` - AgentPattern, builtin_patterns, detect_agent, resolve_pattern

## Decisions Made
- Used `take_writer()` instead of `try_clone_writer()` -- portable-pty 0.8 API only provides take_writer for the write side
- Added `anyhow` crate for ergonomic error handling in PTY operations (not in original plan deps)
- Used `OnceLock` for static pattern storage in detect_agent to safely return references
- Edition 2021 instead of 2024 for broader ecosystem compatibility

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed portable-pty API: try_clone_writer -> take_writer**
- **Found during:** Task 1 (cargo build)
- **Issue:** Plan specified `try_clone_writer()` which does not exist in portable-pty 0.8
- **Fix:** Changed to `take_writer()` which is the actual API
- **Files modified:** openmob_bridge/src/pty_handler.rs
- **Verification:** cargo build succeeds
- **Committed in:** b2cf32f

**2. [Rule 3 - Blocking] Added missing anyhow dependency**
- **Found during:** Task 1 (cargo build)
- **Issue:** pty_handler.rs uses `anyhow::Result` but anyhow was not in Cargo.toml
- **Fix:** Added `anyhow = "1"` to dependencies
- **Files modified:** openmob_bridge/Cargo.toml
- **Verification:** cargo build succeeds
- **Committed in:** b2cf32f

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes necessary for compilation. No scope creep.

## Issues Encountered
None beyond the API deviations documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- PTY handler, ANSI stripping, and patterns ready for BusyDetector (Plan 03-02)
- CLI skeleton ready for full wiring (Plan 03-04)
- axum dependency declared, ready for HTTP server (Plan 03-03)

## Self-Check: PASSED

- All 5 source files exist
- Commit b2cf32f verified in git log
- SUMMARY.md created

---
*Phase: 03-aibridge-cli*
*Completed: 2026-03-24*
