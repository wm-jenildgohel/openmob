---
phase: 03-aibridge-cli
plan: 02
subsystem: bridge
tags: [rust, tokio, pty, idle-detection, injection-queue, crossterm, terminal-raw-mode]

requires:
  - phase: 03-01
    provides: "PtyHandler, ansi::strip_ansi, patterns::resolve_pattern"
provides:
  - "BusyDetector state machine with 100ms tick and 500ms idle threshold"
  - "InjectionQueue FIFO with priority prepend, sync oneshot, max 100"
  - "Bridge orchestrator wiring PTY + detector + queue via 4 tokio tasks"
  - "Terminal raw mode with RAII restore guard"
affects: [03-03, 03-04]

tech-stack:
  added: [tokio-util, terminal_size, crossterm]
  patterns: [Arc<sync::Mutex> for sync PTY access, Arc<tokio::sync::Mutex> for async state, CancellationToken lifecycle, RAII drop guard for terminal restore, spawn_blocking for sync I/O]

key-files:
  created:
    - openmob_bridge/src/busy_detector.rs
    - openmob_bridge/src/queue.rs
    - openmob_bridge/src/bridge.rs
  modified:
    - openmob_bridge/src/main.rs
    - openmob_bridge/Cargo.toml

key-decisions:
  - "std::sync::Mutex for PTY (sync I/O) vs tokio::sync::Mutex for detector/queue (async)"
  - "Option<Receiver> pattern for inject_notify_rx so run() can take ownership without &mut self"
  - "crossterm for raw mode management (RAII guard on drop)"
  - "tokio::runtime::Handle::block_on inside spawn_blocking for detector process_line calls"

patterns-established:
  - "RAII RawModeGuard: crossterm enable/disable raw mode with Drop impl"
  - "spawn_blocking for sync PTY and stdin I/O tasks"
  - "CancellationToken for unified task lifecycle shutdown"
  - "Non-blocking try_send on capacity-1 channel for inject notification"

requirements-completed: [BRG-03, BRG-05, BRG-07]

duration: 4min
completed: 2026-03-24
---

# Phase 03 Plan 02: BusyDetector, Queue, Bridge Summary

**Idle detection state machine (500ms threshold), FIFO injection queue (max 100, priority + sync), and Bridge orchestrator with 4 concurrent tokio tasks wiring PTY read, stdin forward, detector tick, and injection loop**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-24T12:21:13Z
- **Completed:** 2026-03-24T12:26:05Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- BusyDetector with Arc<Mutex> shared state, 100ms tick interval, 500ms idle timeout, regex pattern matching on ANSI-stripped output
- InjectionQueue with FIFO ordering, priority prepend, sync oneshot channel, and 100-item capacity limit
- Bridge orchestrator spawning 4 concurrent tasks: PTY read loop (spawn_blocking), stdin forward (spawn_blocking), detector ticker (async), injection loop (async)
- Terminal raw mode managed via crossterm with RAII drop guard for safe restore on exit/panic

## Task Commits

1. **Task 1: BusyDetector and InjectionQueue modules** - `75d6dd8` (feat)
2. **Task 2: Bridge orchestrator** - `fbfc37e` (feat)

## Files Created/Modified
- `openmob_bridge/src/busy_detector.rs` - BusyDetector state machine with process_line, is_idle, run
- `openmob_bridge/src/queue.rs` - InjectionQueue with enqueue, enqueue_sync, dequeue, clear, len
- `openmob_bridge/src/bridge.rs` - Bridge orchestrator with 4 tokio tasks, notify_enqueue, status getters
- `openmob_bridge/src/main.rs` - Added mod declarations for bridge, busy_detector, queue
- `openmob_bridge/Cargo.toml` - Added tokio-util, terminal_size, crossterm dependencies

## Decisions Made
- Used `std::sync::Mutex` for PTY handler (sync I/O in spawn_blocking) and `tokio::sync::Mutex` for detector/queue state (async access) -- mixing sync and async mutexes intentionally based on access patterns
- Stored inject_notify receiver as `std::sync::Mutex<Option<Receiver>>` so `run()` can take ownership via `.take()` without requiring `&mut self` -- enables Arc<Bridge> sharing with HTTP server
- Used `crossterm` for terminal raw mode instead of manual libc calls -- provides cross-platform RAII guard
- Used `tokio::runtime::Handle::block_on` inside `spawn_blocking` to call async detector.process_line from the sync PTY read loop

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed terminal-size crate name**
- **Found during:** Task 2 (cargo check)
- **Issue:** Plan specified `terminal-size` but the crate uses underscore: `terminal_size`
- **Fix:** Changed Cargo.toml from `terminal-size = "0.4"` to `terminal_size = "0.4"`
- **Files modified:** openmob_bridge/Cargo.toml
- **Committed in:** fbfc37e

**2. [Rule 3 - Blocking] Restructured inject_notify_rx ownership**
- **Found during:** Task 2 (cargo check)
- **Issue:** `tokio::sync::Mutex<Receiver>` borrowed from `&self` couldn't be moved into `tokio::spawn` (requires `'static`)
- **Fix:** Changed to `std::sync::Mutex<Option<Receiver>>` with `.take()` pattern to transfer ownership
- **Files modified:** openmob_bridge/src/bridge.rs
- **Committed in:** fbfc37e

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes necessary for compilation. No scope creep.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Bridge orchestrator complete with full API surface for HTTP server (Plan 03-03)
- Queue and detector accessible via Bridge getters for handler integration
- `paranoid` field removed from Bridge struct (delegated to PtyHandler.inject_text which already handles it)

---
*Phase: 03-aibridge-cli*
*Completed: 2026-03-24*
