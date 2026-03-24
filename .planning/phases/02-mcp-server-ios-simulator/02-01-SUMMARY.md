---
phase: 02-mcp-server-ios-simulator
plan: 01
subsystem: device-automation
tags: [ios, simulator, xcrun, simctl, idb, dart, flutter]

requires:
  - phase: 01-hub-core-android
    provides: Device model, AdbService, DeviceManager, ScreenshotService, UiTreeService, ActionService, ApiServer

provides:
  - SimctlService wrapping xcrun simctl for iOS simulator lifecycle and screenshots
  - IdbService wrapping facebook/idb for iOS UI tree, tap, swipe, type, button
  - Platform-aware Device model with platform and deviceType fields
  - Platform routing in all existing services (DeviceManager, ScreenshotService, UiTreeService, ActionService)
  - Graceful degradation on non-macOS (iOS features silently disabled)

affects: [02-mcp-server-ios-simulator, 03-aibridge-cli]

tech-stack:
  added: [xcrun simctl, facebook/idb]
  patterns: [platform-aware routing in services, optional dependency injection, cached isAvailable checks]

key-files:
  created:
    - openmob_hub/lib/services/simctl_service.dart
    - openmob_hub/lib/services/idb_service.dart
  modified:
    - openmob_hub/lib/models/device.dart
    - openmob_hub/lib/services/device_manager.dart
    - openmob_hub/lib/services/screenshot_service.dart
    - openmob_hub/lib/services/ui_tree_service.dart
    - openmob_hub/lib/services/action_service.dart
    - openmob_hub/lib/main.dart

key-decisions:
  - "SimctlService and IdbService as separate classes (not combined) for independent availability"
  - "Optional nullable DI: services receive SimctlService? and IdbService? -- null means unavailable"
  - "Cached isAvailable: single process check on first call, cached for lifetime"
  - "Platform routing via device.platform field lookup, not ID format heuristics"

patterns-established:
  - "Platform routing: check device.platform == 'ios' then delegate to iOS service, else existing ADB path"
  - "Graceful degradation: idb-dependent features return empty/error when idb null, simctl-dependent features silently skip"
  - "Device.fromSimctl factory: parse runtime string for OS version, map simctl state to device status"

requirements-completed: [DEV-05, UI-03]

duration: 5min
completed: 2026-03-24
---

# Phase 02 Plan 01: iOS Simulator Support Summary

**SimctlService + IdbService for iOS simulator lifecycle, screenshots, UI tree, and input -- platform-routed through existing Hub services with graceful non-macOS degradation**

## Performance

- **Duration:** 5 min
- **Started:** 2026-03-24T11:15:24Z
- **Completed:** 2026-03-24T11:20:24Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Device model extended with platform (android/ios) and deviceType (physical/emulator/simulator) fields including fromSimctl factory
- SimctlService wraps xcrun simctl for listing simulators, capturing screenshots (stdout PNG), app launch/terminate/openurl, and boot
- IdbService wraps facebook/idb for accessibility tree (describe-all), tap, swipe, type text, and hardware button press
- All existing services (DeviceManager, ScreenshotService, UiTreeService, ActionService) now route iOS devices to SimctlService/IdbService
- main.dart checks tool availability at startup and conditionally injects iOS services

## Task Commits

Each task was committed atomically:

1. **Task 1: Add platform field to Device model, create SimctlService and IdbService** - `e1c66dd` (feat)
2. **Task 2: Wire iOS services into DeviceManager, ScreenshotService, UiTreeService, ActionService, main.dart** - `dc0eba1` (feat)

## Files Created/Modified
- `openmob_hub/lib/models/device.dart` - Added platform, deviceType fields and fromSimctl factory
- `openmob_hub/lib/services/simctl_service.dart` - NEW: xcrun simctl wrapper (list, screenshot, launch, terminate, openurl, boot)
- `openmob_hub/lib/services/idb_service.dart` - NEW: idb wrapper (describeAll, tap, swipe, typeText, pressButton)
- `openmob_hub/lib/services/device_manager.dart` - Accepts optional SimctlService/IdbService, merges iOS simulators in refreshDevices()
- `openmob_hub/lib/services/screenshot_service.dart` - Routes iOS screenshots through simctl
- `openmob_hub/lib/services/ui_tree_service.dart` - Routes iOS UI tree through idb (empty list fallback)
- `openmob_hub/lib/services/action_service.dart` - Platform routing for all actions (tap, swipe, type, pressKey, goHome, launchApp, terminateApp, openUrl, longPress)
- `openmob_hub/lib/main.dart` - Initializes SimctlService + IdbService with availability-gated DI

## Decisions Made
- SimctlService and IdbService kept as separate classes since they have independent availability (simctl needs Xcode, idb needs Homebrew + pip)
- Used nullable optional DI pattern: services receive `SimctlService?` / `IdbService?` where null means tool not available on this platform
- Cached `isAvailable` with single process check -- avoids repeated subprocess spawning on every device poll
- Platform routing based on `device.platform` field rather than ID format heuristics (more explicit, no false positives)
- Pinch gesture returns "not supported on iOS" rather than attempting approximation (idb has no multi-touch)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unnecessary non-null assertions**
- **Found during:** Task 2 (dart analyze verification)
- **Issue:** After null check on final fields, Dart 3 promotes to non-nullable, making `!` operator redundant (12 warnings)
- **Fix:** Removed all unnecessary `!` operators across action_service.dart, device_manager.dart, screenshot_service.dart, ui_tree_service.dart
- **Files modified:** All 4 modified service files
- **Verification:** dart analyze lib/ -- zero issues
- **Committed in:** dc0eba1 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor code quality fix. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required. iOS tools (xcrun simctl, idb) are auto-detected at runtime.

## Next Phase Readiness
- iOS simulator support fully integrated into Hub HTTP API
- MCP server (plan 02-02) can call same endpoints for both Android and iOS devices
- On non-macOS, all Android functionality unchanged, no iOS-related errors

---
*Phase: 02-mcp-server-ios-simulator*
*Completed: 2026-03-24*
