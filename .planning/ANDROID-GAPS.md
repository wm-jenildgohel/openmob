# Android Automation Feature Gaps: OpenMob vs Competitors

**Date**: 2026-03-26
**Compared Against**: MobAI (mobai.run/mobai-mcp), mobile-mcp (mobile-next), scrcpy-mcp (JuanCF), mcp-android-emulator (Anjos2), Android-MCP (CursorTouch)

---

## OpenMob Current Android Capabilities

| Category | Feature | Status |
|----------|---------|--------|
| Screen | Screenshot (base64 PNG) | DONE |
| Screen | Preview capture (raw PNG) | DONE |
| UI | Accessibility tree (uiautomator dump) | DONE |
| UI | Filter by text/visibility | DONE |
| Input | Tap (coordinates) | DONE |
| Input | Tap (element index) | DONE |
| Input | Type text (escaped) | DONE |
| Input | Swipe (coords + direction) | DONE |
| Input | Long press | DONE |
| Input | Double tap | DONE |
| Input | Pinch zoom in/out | DONE |
| Input | Key events (all keycodes) | DONE |
| Navigation | Go home | DONE |
| Navigation | Open URL | DONE |
| App | Launch app (monkey) | DONE |
| App | Terminate app (force-stop) | DONE |
| Device | Wake + swipe unlock | DONE |
| Device | List devices (enriched) | DONE |
| Device | WiFi ADB connect | DONE |
| Device | Battery level/status | DONE |
| Device | Screen dimensions | DONE |
| Device | Bridge start/stop | DONE |
| Testing | Run test scripts (multi-step) | DONE |
| Testing | Flutter test runner | DONE |
| Multi-device | Multiple devices listed | DONE |

---

## Gap Analysis: 20 Features

### Legend
- **Competitors**: Which competitor(s) have this feature
- **Difficulty**: Easy (<1 day) / Medium (1-3 days) / Hard (>3 days)
- **QA Value**: Critical / High / Medium / Low
- **Priority**: P0 (must-have) / P1 (should-have) / P2 (nice-to-have) / P3 (low priority)

---

### 1. Screen Mirroring / Streaming (MJPEG or WebSocket)

**Status**: MISSING
**Competitors**: scrcpy-mcp (MJPEG stream + screen recording), MobAI (live preview in desktop app)
**OpenMob**: Only periodic screenshot polling via `GET /screenshot`

**Difficulty**: Hard
**QA Value**: Medium -- most AI agents work fine with periodic screenshots; streaming matters more for human viewers in the Hub UI
**ADB Approach**: `adb exec-out screenrecord --output-format=h264 -` piped to ffmpeg for MJPEG, OR integrate scrcpy as optional backend for low-latency frames (~33ms vs ~500ms)
**Implementation Notes**:
- Option A: WebSocket endpoint that sends JPEG frames at configurable FPS (5-15fps)
- Option B: scrcpy integration via `scrcpy --no-window --v4l2-sink=/dev/videoN` or raw socket
- Option A is self-contained; Option B gives 10-50x faster input but adds external dependency
**Priority**: P2 -- current polling works for AI agents; streaming would improve Hub desktop preview

---

### 2. scrcpy Integration

**Status**: MISSING
**Competitors**: scrcpy-mcp (full integration -- session start/stop, fast screenshots in ~33ms, binary control protocol for input)
**OpenMob**: Pure ADB only

**Difficulty**: Hard
**QA Value**: High -- 10-50x faster screenshots and input; critical for real-time automation
**Approach**: Spawn scrcpy with `--no-window` + control socket. Use scrcpy's binary protocol for input (tap/swipe/type) and video stream for screenshots. Fall back to ADB when scrcpy unavailable.
**Implementation Notes**:
- scrcpy server binary must be pushed to device once
- Control via TCP socket on localhost
- Protocol is documented: https://github.com/Genymobile/scrcpy/blob/master/doc/develop.md
- ADB fallback keeps OpenMob working without scrcpy installed
**Priority**: P1 -- significant performance improvement, but adds optional dependency

---

### 3. App Install / Uninstall

**Status**: MISSING
**Competitors**: mobile-mcp (mobile_install_app, mobile_uninstall_app), MobAI (install APK/IPA, uninstall), scrcpy-mcp (app_install, app_uninstall), mcp-android-emulator (install_apk)
**OpenMob**: Can launch/terminate but NOT install or uninstall

**Difficulty**: Easy
**QA Value**: Critical -- QA testers need to install test builds constantly
**ADB Commands**:
```
# Install
adb -s <serial> install <path-to-apk>
adb -s <serial> install -r <path-to-apk>  # replace existing

# Uninstall
adb -s <serial> uninstall <package-name>
```
**Implementation Notes**:
- Hub: Add `installApp(serial, apkPath)` and `uninstallApp(serial, packageName)` to ActionService
- Routes: `POST /<id>/install` (multipart file upload or local path), `POST /<id>/uninstall`
- MCP: `install_app` and `uninstall_app` tools
- Consider `-r` (replace), `-d` (downgrade), `-g` (grant all permissions) flags
**Priority**: P0 -- table stakes for any mobile automation tool

---

### 4. File Push / Pull

**Status**: MISSING
**Competitors**: scrcpy-mcp (file_push, file_pull, file_list), MobAI (not documented)
**OpenMob**: No file transfer capability

**Difficulty**: Easy
**QA Value**: High -- needed for uploading test data, downloading crash logs, pulling screenshots
**ADB Commands**:
```
adb -s <serial> push <local-path> <remote-path>
adb -s <serial> pull <remote-path> <local-path>
adb -s <serial> shell ls <path>
```
**Implementation Notes**:
- Hub: `pushFile(serial, localPath, remotePath)`, `pullFile(serial, remotePath, localPath)`, `listFiles(serial, path)`
- Routes: `POST /<id>/file/push`, `POST /<id>/file/pull`, `GET /<id>/file/list?path=/sdcard/`
- For push: accept multipart upload or reference local path
- For pull: return file content as base64 or downloadable stream
**Priority**: P1 -- frequently needed in QA workflows

---

### 5. Logcat Streaming

**Status**: MISSING
**Competitors**: mcp-android-emulator (get_logs with filters/levels), scrcpy-mcp (not documented), MobAI (SSE streaming with process/level/tag/content filters), AlexGladkov/claude-in-mobile (logcat with filters)
**OpenMob**: No log access

**Difficulty**: Medium
**QA Value**: High -- essential for debugging test failures, crash investigation
**ADB Commands**:
```
# Last N lines
adb -s <serial> logcat -d -t 100

# Filtered by tag
adb -s <serial> logcat -d -s MyApp:V

# Filtered by level
adb -s <serial> logcat -d *:E   # errors only

# Continuous stream
adb -s <serial> logcat

# Clear buffer
adb -s <serial> logcat -c
```
**Implementation Notes**:
- Option A (simple): `GET /<id>/logcat?lines=100&tag=MyApp&level=E` -- returns last N lines
- Option B (streaming): SSE endpoint `GET /<id>/logcat/stream` for real-time log following
- Option A is easy (1 day), Option B is medium (2-3 days)
- MCP tool: `get_device_logs` with tag/level/lines params
- Store last N lines in memory ring buffer for fast retrieval
**Priority**: P0 -- debugging without logs is painful; every serious tool has this

---

### 6. Clipboard Read / Write

**Status**: MISSING
**Competitors**: scrcpy-mcp (clipboard_get, clipboard_set -- bypasses Android 10+ restrictions via scrcpy), mcp-android-emulator (get_clipboard, set_clipboard)
**OpenMob**: No clipboard access

**Difficulty**: Medium
**QA Value**: Medium -- useful for testing copy/paste flows and data extraction
**ADB Commands**:
```
# Set clipboard (Android 10+, requires special handling)
adb -s <serial> shell am broadcast -a clipper.set -e text "content"
# OR via input: adb shell input keyevent 279 (paste)

# Get clipboard (hard without root or app on Android 10+)
# Pre-Android 10: adb shell service call clipboard 2 s16 com.android.shell
# Android 10+: Requires a helper app or scrcpy
```
**Implementation Notes**:
- Android 10+ severely restricted clipboard access from background
- Without scrcpy: install a tiny helper APK (ClipboardService) that exposes clipboard via broadcast receiver
- With scrcpy: use scrcpy's clipboard sync protocol (clean, no helper needed)
- Phase 1: ADB-based for Android <10 and emulators
- Phase 2: scrcpy-based for Android 10+
**Priority**: P2 -- useful but workarounds exist (type text, screenshot+OCR)

---

### 7. WiFi / Bluetooth / Airplane Mode Toggle

**Status**: MISSING
**Competitors**: Not widely supported in competitors (shell commands available)
**OpenMob**: Not implemented, though ADB commands are documented in SKILL.md

**Difficulty**: Easy
**QA Value**: Medium -- useful for testing offline behavior, network transitions
**ADB Commands**:
```
# WiFi
adb -s <serial> shell svc wifi enable
adb -s <serial> shell svc wifi disable

# Mobile data
adb -s <serial> shell svc data enable
adb -s <serial> shell svc data disable

# Airplane mode
adb -s <serial> shell cmd connectivity airplane-mode enable
adb -s <serial> shell cmd connectivity airplane-mode disable

# Bluetooth (requires root on some devices)
adb -s <serial> shell svc bluetooth enable
adb -s <serial> shell svc bluetooth disable

# Query status
adb -s <serial> shell settings get global airplane_mode_on
adb -s <serial> shell settings get global wifi_on
```
**Implementation Notes**:
- Hub: `toggleConnectivity(serial, type, enabled)` in ActionService
- Route: `POST /<id>/connectivity` with `{"type": "wifi|data|airplane|bluetooth", "enabled": true|false}`
- Some commands may need root on physical devices (Bluetooth especially)
- Always return current state after toggle for verification
**Priority**: P2 -- niche but important for connectivity-dependent app testing

---

### 8. Notification Access

**Status**: MISSING
**Competitors**: Android-MCP (Notification-Tool), scrcpy-mcp (expand_notifications, collapse_panels)
**OpenMob**: No notification access

**Difficulty**: Medium
**QA Value**: High -- QA often needs to verify push notifications, toast messages
**ADB Commands**:
```
# Open notification shade
adb -s <serial> shell cmd statusbar expand-notifications

# Close notification shade
adb -s <serial> shell cmd statusbar collapse

# Read notifications (requires dumpsys)
adb -s <serial> shell dumpsys notification --noredact

# Open quick settings
adb -s <serial> shell cmd statusbar expand-settings
```
**Implementation Notes**:
- Phase 1: `expandNotifications()` and `collapseNotifications()` -- just open/close the shade, then use existing UI tree + screenshot to read content
- Phase 2: `getNotifications()` -- parse `dumpsys notification` output for structured notification data (title, text, package, timestamp)
- Phase 1 is easy (half day), Phase 2 is medium (1-2 days for parsing)
- MCP tool: `get_notifications` returns parsed notification list
**Priority**: P1 -- very common QA scenario

---

### 9. Device Rotation

**Status**: MISSING
**Competitors**: mobile-mcp (mobile_get_orientation, mobile_set_orientation), scrcpy-mcp (rotate_device), mcp-android-emulator (rotate_device)
**OpenMob**: No rotation control

**Difficulty**: Easy
**QA Value**: High -- testing landscape mode is a standard QA task
**ADB Commands**:
```
# Disable auto-rotate
adb -s <serial> shell settings put system accelerometer_rotation 0

# Set rotation (0=natural, 1=90, 2=180, 3=270)
adb -s <serial> shell settings put system user_rotation 0  # portrait
adb -s <serial> shell settings put system user_rotation 1  # landscape

# Get current rotation
adb -s <serial> shell settings get system user_rotation

# Re-enable auto-rotate
adb -s <serial> shell settings put system accelerometer_rotation 1
```
**Implementation Notes**:
- Hub: `rotateDevice(serial, orientation)` and `getOrientation(serial)` in ActionService
- Route: `POST /<id>/rotate` with `{"orientation": "portrait|landscape|reverse_portrait|reverse_landscape"}`
- Route: `GET /<id>/orientation` returns current orientation
- Always disable auto-rotate before setting rotation, restore on demand
**Priority**: P1 -- standard QA requirement

---

### 10. Multi-Device Simultaneous Control

**Status**: PARTIAL
**Competitors**: mobile-mcp (multi-device via device ID), MobAI (free tier: 1 device), scrcpy-mcp (single device per session)
**OpenMob**: Lists multiple devices; all API endpoints accept device ID; bridge start/stop per device. Effectively DONE at API level.

**Difficulty**: N/A (already works)
**QA Value**: High
**Implementation Notes**:
- OpenMob already routes all actions by device serial/ID
- Multiple devices can be bridged simultaneously
- Gap is only in MCP: each MCP tool requires `device_id`, which is already implemented
- Potential improvement: batch operations across multiple devices (run same test on all devices)
**Priority**: P3 -- already functional; batch mode is a future enhancement

---

### 11. Screen Recording

**Status**: MISSING
**Competitors**: scrcpy-mcp (screen_record_start, screen_record_stop with file transfer), MobAI (not documented as MCP tool)
**OpenMob**: No recording

**Difficulty**: Medium
**QA Value**: High -- recording test sessions for bug reports is extremely valuable
**ADB Commands**:
```
# Start recording (max 180 seconds)
adb -s <serial> shell screenrecord /sdcard/recording.mp4

# With options
adb -s <serial> shell screenrecord --time-limit 30 --size 720x1280 --bit-rate 4000000 /sdcard/recording.mp4

# Stop: send Ctrl-C (kill the process)
adb -s <serial> shell pkill -SIGINT screenrecord

# Pull the file
adb -s <serial> pull /sdcard/recording.mp4 ./recording.mp4
```
**Implementation Notes**:
- Hub: `startRecording(serial, options)` and `stopRecording(serial)` in a new RecordingService
- The ADB screenrecord process runs in background; track PID for stopping
- On stop: pull the MP4 file to host and return path or base64
- Route: `POST /<id>/record/start`, `POST /<id>/record/stop`
- Max 180 seconds per ADB limitation (3 minutes)
- Consider chaining recordings for longer sessions
**Priority**: P1 -- high value for QA bug reporting workflows

---

### 12. Wake / Unlock (Enhanced)

**Status**: PARTIAL
**Competitors**: scrcpy-mcp (screen_on, screen_off as separate tools), mcp-android-emulator (no specific tool)
**OpenMob**: Has `unlockDevice()` which does WAKEUP + swipe + MENU. Also exposed via `POST /<id>/unlock`.

**Difficulty**: Easy (for enhancements)
**QA Value**: Medium
**ADB Commands**:
```
# Already implemented:
adb shell input keyevent 224  # WAKEUP
adb shell input keyevent 223  # SLEEP (screen off)
adb shell input keyevent 82   # MENU (dismiss keyguard)

# Check if screen is on
adb shell dumpsys power | grep "Display Power"
# or
adb shell dumpsys display | grep "mScreenState"
```
**Implementation Notes**:
- Current unlock is functional but could add:
  - Separate `screenOn()` / `screenOff()` methods
  - `isScreenOn()` query: parse `dumpsys power` for "Display Power: state=ON"
  - PIN/pattern unlock support (type PIN after wake)
- Route additions: `POST /<id>/screen-on`, `POST /<id>/screen-off`, `GET /<id>/screen-state`
**Priority**: P2 -- current implementation covers 90% of cases

---

### 13. Status Bar Info (Battery, Signal, Time)

**Status**: PARTIAL
**Competitors**: mcp-android-emulator (device_info), MobAI (performance metrics), scrcpy-mcp (device_info with battery)
**OpenMob**: Already collects battery level/status, screen size, OS version, SDK during device enrichment. Available via `GET /devices/{id}`.

**Difficulty**: Easy (for additional fields)
**QA Value**: Low
**ADB Commands**:
```
# Already collected: battery, screen size, OS version
# Additional:
adb -s <serial> shell dumpsys telephony.registry | grep mSignalStrength
adb -s <serial> shell settings get system time_12_24
adb -s <serial> shell date
adb -s <serial> shell dumpsys connectivity | grep "NetworkAgentInfo"
```
**Implementation Notes**:
- Add signal strength and network type to device enrichment
- Add current time from device
- Add WiFi SSID if connected
- Minimal effort: extend `_enrichDevice()` in DeviceManager
**Priority**: P3 -- battery already covered; signal/time are rarely needed by AI agents

---

### 14. Keyboard Detection

**Status**: MISSING
**Competitors**: mcp-android-emulator (is_keyboard_visible)
**OpenMob**: No keyboard detection

**Difficulty**: Easy
**QA Value**: High -- knowing if keyboard is visible affects tap coordinates and test flow
**ADB Commands**:
```
# Check if keyboard is showing
adb -s <serial> shell dumpsys input_method | grep "mInputShown"
# mInputShown=true means keyboard is visible

# Alternative: check window visibility
adb -s <serial> shell dumpsys window InputMethod | grep "mHasSurface"
```
**Implementation Notes**:
- Hub: `isKeyboardVisible(serial)` in ActionService or a new DeviceStateService
- Route: `GET /<id>/keyboard-state` returns `{"visible": true, "type": "soft"}`
- Also useful: `dismissKeyboard(serial)` via `adb shell input keyevent 111` (Escape) or Back
- Add to UI tree responses as metadata: `{"nodes": [...], "keyboardVisible": true}`
**Priority**: P1 -- directly impacts automation reliability

---

### 15. Wait for Element

**Status**: MISSING (workaround exists via scroll-to-find pattern in SKILL.md)
**Competitors**: mcp-android-emulator (wait_for_element, wait_for_element_gone, wait_for_ui_stable), MobAI DSL (wait_for with timeout)
**OpenMob**: Agent must manually poll ui-tree in a loop

**Difficulty**: Medium
**QA Value**: Critical -- reduces test flakiness dramatically
**Approach**: Poll `uiautomator dump` in a loop with timeout
```
# Pseudo-logic:
# 1. Set timeout (default 10s)
# 2. Loop: dump UI tree, search for element by text/resourceId/contentDesc
# 3. If found: return element
# 4. If timeout: return failure
# 5. Sleep 500ms between polls
```
**Implementation Notes**:
- Hub: `waitForElement(serial, {text?, resourceId?, contentDesc?, timeout, interval})` in ActionService
- Route: `POST /<id>/wait-for` with `{"text": "Welcome", "timeout": 10000, "interval": 500}`
- Also implement: `waitForElementGone` (wait until element disappears)
- Also implement: `waitForUiStable` (wait until two consecutive dumps are identical)
- MCP tool: `wait_for_element` -- reduces agent token usage vs manual polling
**Priority**: P0 -- single most impactful reliability improvement

---

### 16. Element Screenshot

**Status**: MISSING
**Competitors**: Not commonly implemented (can be achieved with crop)
**OpenMob**: Full screen capture only

**Difficulty**: Medium
**QA Value**: Medium -- useful for visual comparison of specific components
**Approach**:
```
# 1. Get element bounds from UI tree
# 2. Take full screenshot
# 3. Crop to element bounds using image library
```
**Implementation Notes**:
- Hub: `captureElementScreenshot(serial, index)` in ScreenshotService
- Get bounds from UiTreeService, capture full screenshot, crop in Dart using `image` package
- Route: `GET /<id>/screenshot?element=5` to capture only element at index 5
- Dart `image` package can crop PNG in memory
- Alternative: return bounds metadata with screenshot so client can crop
**Priority**: P2 -- full screenshot + bounds info usually sufficient

---

### 17. Drag and Drop

**Status**: MISSING (swipe exists but drag-drop has different semantics)
**Competitors**: scrcpy-mcp (drag_drop), mcp-android-emulator (drag), Android-MCP (Drag-Tool)
**OpenMob**: Has swipe, which can simulate simple drags, but no explicit drag-drop semantic

**Difficulty**: Easy
**QA Value**: Medium -- needed for apps with drag-to-reorder, drag-to-delete
**ADB Commands**:
```
# ADB drag is essentially a slow swipe
adb -s <serial> shell input draganddrop <x1> <y1> <x2> <y2> <duration_ms>
# Available on Android 12+ (API 31+)

# Fallback for older Android: long slow swipe
adb -s <serial> shell input swipe <x1> <y1> <x2> <y2> 2000
```
**Implementation Notes**:
- Hub: `dragDrop(serial, x1, y1, x2, y2, durationMs)` in ActionService
- Use `input draganddrop` on API 31+, fall back to slow swipe on older
- Route: `POST /<id>/drag` with `{"x1":100, "y1":200, "x2":300, "y2":400, "duration":2000}`
- Also add as gesture type: `gesture(serial, 'drag', params)`
- Check SDK version from device enrichment to choose command
**Priority**: P2 -- niche use case but easy to add

---

### 18. Text Selection (Select / Copy / Paste)

**Status**: MISSING
**Competitors**: mcp-android-emulator (select_all, clear_input)
**OpenMob**: Can type text but cannot select, copy, or paste

**Difficulty**: Easy
**QA Value**: Medium -- needed for testing edit flows
**ADB Commands**:
```
# Select all
adb -s <serial> shell input keyevent 29 --meta 0x70000  # Ctrl+A (API 24+)
# OR
adb -s <serial> shell input keyevent KEYCODE_MOVE_HOME
adb -s <serial> shell input keyevent --shift KEYCODE_MOVE_END

# Copy
adb -s <serial> shell input keyevent 31 --meta 0x70000  # Ctrl+C

# Paste
adb -s <serial> shell input keyevent 50 --meta 0x70000  # Ctrl+V

# Cut
adb -s <serial> shell input keyevent 52 --meta 0x70000  # Ctrl+X

# Clear input (select all + delete)
# select_all + keyevent 67 (backspace)
```
**Implementation Notes**:
- Hub: `selectAll(serial)`, `copy(serial)`, `paste(serial)`, `cut(serial)`, `clearInput(serial)` in ActionService
- Route: `POST /<id>/text-action` with `{"action": "select_all|copy|paste|cut|clear"}`
- Key meta flags: Ctrl = 0x70000 on some versions, or use KEYCODE constants
- `clearInput` is very useful: select all + delete
**Priority**: P2 -- useful but not blocking

---

### 19. Permission Handling

**Status**: MISSING
**Competitors**: Not commonly implemented as dedicated tools (handled via `pm grant` in shell)
**OpenMob**: No permission management

**Difficulty**: Easy
**QA Value**: High -- permission dialogs frequently break automation flows
**ADB Commands**:
```
# Grant permission
adb -s <serial> shell pm grant <package> <permission>
# Example: adb shell pm grant com.myapp android.permission.CAMERA

# Revoke permission
adb -s <serial> shell pm revoke <package> <permission>

# Grant all permissions on install
adb -s <serial> install -g <apk>

# List permissions for app
adb -s <serial> shell dumpsys package <package> | grep "permission"

# List all runtime permissions
adb -s <serial> shell pm list permissions -g -d
```
**Implementation Notes**:
- Hub: `grantPermission(serial, package, permission)`, `revokePermission(serial, package, permission)`, `grantAllPermissions(serial, package)`
- Route: `POST /<id>/permission` with `{"package":"com.app", "permission":"android.permission.CAMERA", "grant":true}`
- Integrate with install: `-g` flag grants all permissions at install time
- Also: detect permission dialogs in UI tree and auto-dismiss ("Allow" button)
**Priority**: P1 -- permission dialogs are the #1 cause of automation test failures

---

### 20. WebView Inspection

**Status**: MISSING
**Competitors**: MobAI (full WebView support: web_list_pages, web_get_dom, web_click, web_type, web_execute_js, web_navigate via Chrome DevTools Protocol)
**OpenMob**: No WebView support

**Difficulty**: Hard
**QA Value**: High -- hybrid apps (WebView-based) are extremely common
**Approach**:
```
# Enable WebView debugging (must be set in app code):
# WebView.setWebContentsDebuggingEnabled(true)

# Discover debuggable WebViews
curl http://localhost:CHROME_DEVTOOLS_PORT/json

# Forward Chrome DevTools port
adb -s <serial> forward tcp:9222 localabstract:chrome_devtools_remote
# OR for specific WebView:
adb -s <serial> forward tcp:9222 localabstract:webview_devtools_remote_<pid>

# Then use Chrome DevTools Protocol (CDP):
# - Runtime.evaluate (execute JS)
# - DOM.getDocument (get DOM tree)
# - DOM.querySelector (find elements)
# - Input.dispatchMouseEvent (click)
# - Page.navigate (navigate URL)
```
**Implementation Notes**:
- This is a substantial feature requiring Chrome DevTools Protocol client
- Phase 1: Basic web page listing and JS execution
- Phase 2: DOM tree, CSS selector-based clicking, form filling
- Requires: WebView debugging enabled in the target app
- Use `puppeteer-core` or raw CDP WebSocket in MCP server
- Hub: new WebViewService with CDP client
- MobAI has the best implementation here; study their approach
**Priority**: P1 -- hybrid apps are >50% of mobile apps; major competitive gap

---

## Additional Features Found in Competitors (Not in Original 20)

### 21. List Installed Apps

**Status**: MISSING
**Competitors**: mobile-mcp (mobile_list_apps), MobAI (list_apps), scrcpy-mcp (app_list), mcp-android-emulator (list_packages)
**OpenMob**: Cannot list installed apps

**Difficulty**: Easy
**QA Value**: High -- needed to verify installs, check package names
**ADB Commands**:
```
adb -s <serial> shell pm list packages         # all
adb -s <serial> shell pm list packages -3      # third-party only
adb -s <serial> shell pm list packages -s      # system only
adb -s <serial> shell dumpsys package <pkg>    # detailed info
```
**Priority**: P0 -- basic capability everyone else has

---

### 22. Get Current Activity / App

**Status**: MISSING
**Competitors**: scrcpy-mcp (app_current), mcp-android-emulator (get_current_activity), MobAI (DSL observe)
**OpenMob**: No way to know which app/activity is in foreground

**Difficulty**: Easy
**QA Value**: High -- essential for verifying navigation
**ADB Commands**:
```
adb -s <serial> shell dumpsys activity activities | grep "mResumedActivity"
# OR
adb -s <serial> shell dumpsys window | grep -E "mCurrentFocus|mFocusedApp"
```
**Priority**: P0 -- basic state query needed for test assertions

---

### 23. Clear App Data

**Status**: MISSING
**Competitors**: mcp-android-emulator (clear_app_data), MobAI (via shell)
**OpenMob**: Can terminate but not reset app state

**Difficulty**: Easy
**QA Value**: Critical -- clean state is essential for repeatable tests
**ADB Commands**:
```
adb -s <serial> shell pm clear <package>
```
**Priority**: P0 -- fundamental for test isolation

---

### 24. Shell Command Execution

**Status**: MISSING
**Competitors**: Android-MCP (Shell-Tool), scrcpy-mcp (shell_exec)
**OpenMob**: No raw shell access

**Difficulty**: Easy
**QA Value**: Medium -- escape hatch for anything not covered by specific tools
**ADB Commands**:
```
adb -s <serial> shell <command>
```
**Implementation Notes**:
- Safety concern: unrestricted shell access is powerful but risky
- Consider: allowlist of safe commands, or document the security implications
- Route: `POST /<id>/shell` with `{"command": "pm list packages"}`
**Priority**: P2 -- useful escape hatch but security trade-off

---

### 25. Scroll to Text / Find Element

**Status**: MISSING (documented as manual pattern in SKILL.md)
**Competitors**: mcp-android-emulator (scroll_to_text, tap_text, tap_element)
**OpenMob**: Agent must manually loop scroll + check ui-tree

**Difficulty**: Medium
**QA Value**: High -- very common automation pattern
**Approach**: Loop: swipe up, dump UI tree, check for text match. Repeat until found or max scrolls.
**Priority**: P1 -- reduces agent complexity significantly

---

## Priority Summary

### P0 -- Must Have (blocking competitive gaps)
| # | Feature | Difficulty | QA Value |
|---|---------|-----------|----------|
| 3 | App Install/Uninstall | Easy | Critical |
| 5 | Logcat (snapshot mode) | Easy | High |
| 15 | Wait for Element | Medium | Critical |
| 21 | List Installed Apps | Easy | High |
| 22 | Get Current Activity | Easy | High |
| 23 | Clear App Data | Easy | Critical |

### P1 -- Should Have (significant competitive advantage)
| # | Feature | Difficulty | QA Value |
|---|---------|-----------|----------|
| 2 | scrcpy Integration | Hard | High |
| 4 | File Push/Pull | Easy | High |
| 8 | Notification Access | Medium | High |
| 9 | Device Rotation | Easy | High |
| 11 | Screen Recording | Medium | High |
| 14 | Keyboard Detection | Easy | High |
| 19 | Permission Handling | Easy | High |
| 20 | WebView Inspection | Hard | High |
| 25 | Scroll to Text | Medium | High |

### P2 -- Nice to Have
| # | Feature | Difficulty | QA Value |
|---|---------|-----------|----------|
| 1 | Screen Mirroring/Streaming | Hard | Medium |
| 6 | Clipboard Read/Write | Medium | Medium |
| 7 | Connectivity Toggles | Easy | Medium |
| 12 | Wake/Unlock Enhanced | Easy | Medium |
| 16 | Element Screenshot | Medium | Medium |
| 17 | Drag and Drop | Easy | Medium |
| 18 | Text Selection | Easy | Medium |
| 24 | Shell Command Execution | Easy | Medium |

### P3 -- Low Priority
| # | Feature | Difficulty | QA Value |
|---|---------|-----------|----------|
| 10 | Multi-Device (batch ops) | Medium | Medium |
| 13 | Status Bar Info (extended) | Easy | Low |

---

## Recommended Implementation Order

**Sprint 1 (P0 -- 3-4 days)**:
1. List Installed Apps (2 hours)
2. Get Current Activity (2 hours)
3. Clear App Data (1 hour)
4. App Install/Uninstall (half day)
5. Logcat snapshot (half day)
6. Wait for Element + waitForGone + waitForStable (1-2 days)

**Sprint 2 (P1 Easy -- 2-3 days)**:
1. Device Rotation (half day)
2. Keyboard Detection (half day)
3. Permission Handling (half day)
4. File Push/Pull (1 day)

**Sprint 3 (P1 Medium -- 3-4 days)**:
1. Notification Access (1 day)
2. Screen Recording (1-2 days)
3. Scroll to Text / Find Element (1 day)

**Sprint 4 (P1 Hard -- 5+ days)**:
1. scrcpy Integration (3-5 days)
2. WebView Inspection (3-5 days)

---

## Sources

- [MobAI Website](https://mobai.run/) -- Feature overview, March 2026
- [MobAI MCP Server](https://github.com/MobAI-App/mobai-mcp) -- Tool definitions
- [MobAI Documentation](https://mobai.run/docs/) -- Full API reference, DSL actions, WebView
- [mobile-mcp](https://github.com/mobile-next/mobile-mcp) -- Tool list, orientation, install/uninstall
- [scrcpy-mcp](https://github.com/JuanCF/scrcpy-mcp) -- 34 tools including recording, clipboard, file ops
- [mcp-android-emulator](https://github.com/Anjos2/mcp-android-emulator) -- 40 tools, most comprehensive feature set
- [Android-MCP](https://github.com/CursorTouch/Android-MCP) -- Drag, notifications, shell tools
- [scrcpy](https://github.com/Genymobile/scrcpy) -- Screen mirroring protocol documentation
