---
phase: 01-hub-core-android-device-layer
plan: 02
subsystem: services
tags: [rxdart, adb, device-discovery, screenshot, uiautomator, xml, base64, behaviorsubject]

requires:
  - phase: 01-01
    provides: AdbService wrapper, Device/UiNode models, constants
provides:
  - DeviceManager with discovery, metadata enrichment, WiFi connect, bridge state via BehaviorSubject
  - ScreenshotService with binary-safe PNG capture via exec-out and base64 encoding
  - UiTreeService with uiautomator XML dump, parsing, sequential indexing, and filtering
affects: [01-03, 01-04, mcp-server]

tech-stack:
  added: []
  patterns: [BehaviorSubject for reactive service state, exec-out for binary-safe ADB output, uiautomator dump /dev/tty for stdout XML]

key-files:
  created:
    - openmob_hub/lib/services/device_manager.dart
    - openmob_hub/lib/services/screenshot_service.dart
    - openmob_hub/lib/services/ui_tree_service.dart
  modified: []

key-decisions:
  - "exec-out instead of shell for screencap to avoid PTY binary corruption"
  - "uiautomator dump /dev/tty for direct stdout XML instead of file-based dump"
  - "Sequential index assignment before filtering for stable node indices"
  - "PNG IHDR header parsing for screenshot dimensions instead of separate wm size call"

patterns-established:
  - "Service pattern: AdbService dependency injection via constructor"
  - "Reactive state: BehaviorSubject.seeded([]) with ValueStream getter"
  - "Error resilience: try/catch with graceful fallback (empty list, basic device entry)"

requirements-completed: [DEV-01, DEV-02, DEV-03, DEV-04, DEV-06, DEV-07, UI-01, UI-02, UI-04, UI-05]

duration: 2min
completed: 2026-03-24
---

# Phase 01 Plan 02: Core ADB Services Summary

**DeviceManager with rxdart BehaviorSubject discovery/enrichment, ScreenshotService with exec-out binary-safe capture, UiTreeService with uiautomator XML parsing and stable indexed filtering**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-24T10:40:31Z
- **Completed:** 2026-03-24T10:42:04Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- DeviceManager discovers USB/WiFi/emulator devices with parallel ADB metadata enrichment (model, OS, screen size, battery)
- WiFi ADB connect workflow (tcpip + ip route + connect) fully implemented
- ScreenshotService captures PNG via exec-out screencap -p with PNG header dimension parsing
- UiTreeService dumps via uiautomator, parses XML with xml package, assigns stable sequential indices before filtering
- All state flows through rxdart BehaviorSubject -- zero setState anywhere

## Task Commits

1. **Task 1: Build DeviceManager with discovery, metadata enrichment, WiFi connect, and rxdart state** - `4cb4016` (feat)
2. **Task 2: Build ScreenshotService and UiTreeService** - `9b1f6f5` (feat)

## Files Created/Modified
- `openmob_hub/lib/services/device_manager.dart` - Device discovery, metadata enrichment, WiFi connect, bridge state management via BehaviorSubject
- `openmob_hub/lib/services/screenshot_service.dart` - Binary-safe PNG capture via exec-out with base64 encoding and IHDR dimension parsing
- `openmob_hub/lib/services/ui_tree_service.dart` - UI tree dump via uiautomator, XML parsing, sequential indexing, UiTreeFilter support

## Decisions Made
- Used exec-out instead of shell for screencap to avoid PTY binary corruption (per research pitfall #1)
- uiautomator dump /dev/tty for direct stdout XML avoids file I/O on device
- Sequential indices assigned before filtering so node indices remain stable regardless of filter criteria
- PNG IHDR header parsing (offset 16/20 big-endian) for dimensions instead of a separate wm size ADB call

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All three core services complete and dart-analyze clean
- Ready for Plan 03 (HTTP route wiring to expose these services via shelf API)
- DeviceManager, ScreenshotService, UiTreeService all take AdbService via constructor injection

## Self-Check: PASSED

All 3 files verified present. Both task commits (4cb4016, 9b1f6f5) confirmed in git history.

---
*Phase: 01-hub-core-android-device-layer*
*Completed: 2026-03-24*
