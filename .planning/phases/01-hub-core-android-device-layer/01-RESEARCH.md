# Phase 1: Hub Core + Android Device Layer - Research

**Researched:** 2026-03-24
**Domain:** Flutter Desktop Hub with embedded HTTP server, ADB-based Android device automation, reactive state management
**Confidence:** HIGH

## Summary

Phase 1 delivers the foundational Flutter Desktop Hub application -- the central nervous system of OpenMob. This is a greenfield Flutter desktop project that must: (1) embed an HTTP REST API server on localhost:8686, (2) discover and manage Android devices via ADB, (3) capture screenshots and extract UI accessibility trees, (4) execute all device interaction primitives (tap, swipe, type, keys, app launch/terminate, URLs, advanced gestures), and (5) present a basic desktop UI showing connected devices with real-time status.

The Hub uses `shelf` + `shelf_router` for the embedded HTTP server (Dart team maintained, composable middleware, proper routing), `rxdart` with BehaviorSubject for reactive state management (per project preference -- no setState), and `dart:io Process` for spawning ADB commands. All ADB commands are well-documented and stable. The primary technical risks are: ADB binary path resolution across platforms, `uiautomator dump` failing on animated screens, and WiFi ADB connection instability. The phase is entirely self-contained with no dependency on MCP server or AiBridge.

**Primary recommendation:** Build the HTTP API layer first (shelf server + route stubs), then the ADB service layer (device discovery, screenshot, UI tree, actions), then wire them together with rxdart state streams, and finally add the Flutter Desktop UI consuming those streams.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
All implementation choices are at Claude's discretion -- discuss phase was skipped per user setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

Key constraints from PROJECT.md:
- Use rxdart instead of setState (per user preference)
- Flutter Desktop for cross-platform support
- ADB for all Android automation
- Localhost-only HTTP binding (127.0.0.1)
- No cloud dependency, no telemetry, no license validation
- MIT licensed

### Claude's Discretion
All implementation choices are at Claude's discretion.

### Deferred Ideas (OUT OF SCOPE)
None -- discuss phase skipped.
</user_constraints>

## Project Constraints (from CLAUDE.md)

- Use rxdart always -- never setState
- Do not build app until prompted
- Never waste time creating tests
- Never build APK until tried
- Do not create unnecessary README or docs
- Do not waste tokens on unnecessary documentation

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEV-01 | List all connected Android devices (USB, WiFi, emulator) with model, OS version, screen size | ADB `adb devices` parsing + `getprop` commands for metadata |
| DEV-02 | Connect to Android devices via USB using ADB | ADB auto-detects USB devices -- `adb devices` shows them |
| DEV-03 | Connect to Android devices via WiFi ADB | `adb tcpip 5555` + `adb connect IP:PORT` workflow; Android 11+ uses `adb pair` |
| DEV-04 | Connect to Android emulators (auto-detected via ADB) | Emulators appear as `emulator-XXXX` in `adb devices` output |
| DEV-06 | Retrieve device metadata (model, OS, screen resolution, battery) | `getprop ro.product.model`, `ro.build.version.release`, `wm size`, `dumpsys battery` |
| DEV-07 | Start and stop device automation bridge per device | Per-device ADB session tracking with rxdart BehaviorSubject state |
| UI-01 | Capture screenshot as base64-encoded PNG | `adb exec-out screencap -p` piped to base64 encoding in Dart |
| UI-02 | Extract UI accessibility tree from Android (uiautomator dump) | `adb exec-out uiautomator dump /dev/tty` for direct stdout XML output |
| UI-04 | Stable element index numbers for AI reference | Parse XML nodes, assign sequential index per visible element |
| UI-05 | Filter UI tree by text regex, bounds, visibility | Post-parse XML filtering on node attributes |
| ACT-01 | Tap at specific x,y coordinates | `adb shell input tap X Y` |
| ACT-02 | Tap UI element by index (resolves to center of bounds) | Parse bounds `[left,top][right,bottom]` from UI tree, compute center, then tap |
| ACT-03 | Type text into focused input field | `adb shell input text "STRING"` (special chars need escaping) |
| ACT-04 | Swipe gestures with configurable distance/duration | `adb shell input swipe X1 Y1 X2 Y2 DURATION_MS` |
| ACT-05 | Press hardware/soft keys | `adb shell input keyevent CODE` -- Home(3), Back(4), Enter(66), VolUp(24), VolDown(25), Power(26) |
| ACT-06 | Navigate to home screen | `adb shell input keyevent 3` (KEYCODE_HOME) |
| ACT-07 | Launch app by package name | `adb shell monkey -p PACKAGE -c android.intent.category.LAUNCHER 1` |
| ACT-08 | Terminate/kill running app | `adb shell am force-stop PACKAGE` |
| ACT-09 | Open URL or deep link | `adb shell am start -a android.intent.action.VIEW -d "URL"` |
| ACT-10 | Advanced gestures (long press, pinch, multi-touch) | Long press: `swipe X Y X Y 1500`; Pinch: parallel swipe commands; Multi-touch: `&` chained swipes |
| HUB-01 | Display connected devices with real-time status | rxdart BehaviorSubject device list stream -> ValueStreamBuilder in UI |
| HUB-06 | Run entirely locally with zero cloud dependency | All localhost, no external APIs, no telemetry |
| HUB-07 | Works on Windows, macOS, Linux | Flutter Desktop cross-platform; ADB available on all three |
| FREE-01 | No usage quotas, no daily limits, no device limits | No artificial limits in code |
| FREE-02 | Fully offline -- no license validation, no telemetry | No network calls except localhost |
| FREE-03 | All components bind to localhost only | shelf server binds to `InternetAddress.loopbackIPv4` (127.0.0.1) |
| FREE-04 | MIT licensed, fully open source | MIT LICENSE file at project root |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Flutter | 3.41.5 | Desktop UI framework | Verified installed. Cross-platform desktop (Win/Mac/Linux) from single codebase. Mature desktop support. |
| Dart | 3.11.3 | Language runtime | Ships with Flutter 3.41.5. Verified installed. |
| shelf | 1.4.2 | HTTP server middleware | Dart team maintained (dart-lang/shelf). Composable middleware, adapts to dart:io HttpServer via shelf_io. Lightweight -- no framework bloat. |
| shelf_router | 1.1.4 | HTTP request routing | Pairs with shelf. Pattern-based routing (`router.get('/api/v1/devices', handler)`). Dart team maintained. |
| rxdart | 0.28.0 | Reactive state management | Project preference. BehaviorSubject for cached latest value, CombineLatest for composite state, Debounce for polling. |
| ADB | 34.0.4 | Android device automation | Verified installed. Standard Android Platform-Tools. All device ops go through ADB. |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| rxdart_flutter | 0.0.2 | Flutter widgets for rxdart | ValueStreamBuilder, ValueStreamConsumer for binding BehaviorSubject to widget tree |
| window_manager | 0.5.1 | Desktop window control | Window title, size, position, minimize-to-tray behavior |
| process_run | 1.3.1+1 | Cross-platform process execution | Finding ADB binary path cross-platform (which/where), running shell commands |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| shelf + shelf_router | Raw dart:io HttpServer | Raw HttpServer has no routing, no middleware composition. shelf adds ~50KB but saves significant manual routing code |
| shelf + shelf_router | dart_frog | dart_frog is a full framework (code generation, routing conventions). Overkill for an embedded API server with ~15 endpoints |
| process_run | Raw dart:io Process | Raw Process works but process_run handles PATH resolution, `which` command, and cross-platform executable lookup automatically |
| rxdart BehaviorSubject | StreamController + StreamBuilder | BehaviorSubject caches last value for new subscribers. Raw StreamController requires manual value tracking. rxdart is project standard. |

**Installation:**
```bash
# Create Flutter desktop project
flutter create --platforms=linux,macos,windows openmob_hub
cd openmob_hub

# pubspec.yaml dependencies:
# shelf: ^1.4.2
# shelf_router: ^1.1.4
# rxdart: ^0.28.0
# rxdart_flutter: ^0.0.2
# window_manager: ^0.5.1
# process_run: ^1.3.1
```

## Architecture Patterns

### Recommended Project Structure

```
openmob_hub/
├── lib/
│   ├── main.dart                    # Entry point: start HTTP server + Flutter app
│   ├── app.dart                     # MaterialApp with routes
│   ├── core/
│   │   ├── constants.dart           # Ports, timeouts, key codes
│   │   └── extensions.dart          # Utility extensions
│   ├── server/
│   │   ├── api_server.dart          # shelf server setup, bind to 127.0.0.1:8686
│   │   ├── routes/
│   │   │   ├── device_routes.dart   # /api/v1/devices/* endpoints
│   │   │   ├── action_routes.dart   # /api/v1/devices/:id/tap, /swipe, etc.
│   │   │   └── health_routes.dart   # /health, /status
│   │   └── middleware/
│   │       ├── cors_middleware.dart  # CORS for local dev tools
│   │       └── json_middleware.dart  # Content-type enforcement
│   ├── services/
│   │   ├── adb_service.dart         # ADB command execution wrapper
│   │   ├── device_manager.dart      # Device discovery, tracking, state
│   │   ├── screenshot_service.dart  # Screenshot capture + base64 encoding
│   │   ├── ui_tree_service.dart     # UI tree dump, parse, index, filter
│   │   └── action_service.dart      # Tap, swipe, type, keys, app mgmt
│   ├── models/
│   │   ├── device.dart              # Device model (serial, model, OS, screen, battery, status)
│   │   ├── ui_node.dart             # Parsed UI tree node with index
│   │   └── action_result.dart       # Action execution result
│   └── ui/
│       ├── screens/
│       │   ├── home_screen.dart     # Main device list screen
│       │   └── device_detail.dart   # Single device view with actions
│       └── widgets/
│           ├── device_card.dart     # Device card with status indicator
│           └── connection_badge.dart # USB/WiFi/Emulator badge
├── linux/                           # Linux desktop runner
├── macos/                           # macOS desktop runner
├── windows/                         # Windows desktop runner
└── pubspec.yaml
```

### Pattern 1: Embedded HTTP Server in Flutter Desktop

**What:** Start a shelf HTTP server alongside the Flutter app in the same Dart isolate (or a separate isolate for heavy operations).
**When to use:** Always -- the Hub IS the HTTP API server.
**Example:**
```dart
// lib/server/api_server.dart
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class ApiServer {
  HttpServer? _server;
  final Router _router = Router();

  ApiServer() {
    _router.get('/health', _health);
    _router.get('/api/v1/devices', _listDevices);
    _router.get('/api/v1/devices/<id>/screenshot', _getScreenshot);
    _router.get('/api/v1/devices/<id>/ui-tree', _getUiTree);
    _router.post('/api/v1/devices/<id>/tap', _tap);
    _router.post('/api/v1/devices/<id>/swipe', _swipe);
    _router.post('/api/v1/devices/<id>/type', _typeText);
    _router.post('/api/v1/devices/<id>/keyevent', _keyEvent);
    _router.post('/api/v1/devices/<id>/launch', _launchApp);
    _router.post('/api/v1/devices/<id>/terminate', _terminateApp);
    _router.post('/api/v1/devices/<id>/open-url', _openUrl);
    _router.post('/api/v1/devices/<id>/gesture', _gesture);
    _router.post('/api/v1/devices/<id>/bridge/start', _startBridge);
    _router.post('/api/v1/devices/<id>/bridge/stop', _stopBridge);
  }

  Future<void> start() async {
    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_router.call);
    // CRITICAL: bind to loopback only
    _server = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4, // 127.0.0.1
      8686,
    );
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }
}
```
**Source:** [shelf pub.dev](https://pub.dev/packages/shelf), [shelf_router pub.dev](https://pub.dev/packages/shelf_router)

### Pattern 2: rxdart BehaviorSubject Service Pattern

**What:** Each service exposes a BehaviorSubject stream. UI consumes via ValueStreamBuilder.
**When to use:** All state management in this project.
**Example:**
```dart
// lib/services/device_manager.dart
import 'package:rxdart/rxdart.dart';

class DeviceManager {
  final _devices = BehaviorSubject<List<Device>>.seeded([]);

  // Expose as read-only stream
  ValueStream<List<Device>> get devices$ => _devices.stream;

  // Current value without subscribing
  List<Device> get currentDevices => _devices.value;

  Future<void> refreshDevices() async {
    final result = await _adbService.listDevices();
    _devices.add(result);
  }

  void dispose() {
    _devices.close();
  }
}

// In widget:
// ValueStreamBuilder<List<Device>>(
//   stream: deviceManager.devices$,
//   builder: (context, snapshot) => ListView(...),
// )
```
**Source:** [rxdart pub.dev](https://pub.dev/packages/rxdart)

### Pattern 3: ADB Command Execution Wrapper

**What:** A single service class that wraps all ADB shell commands with proper serial targeting, timeout handling, and error parsing.
**When to use:** Every ADB interaction.
**Example:**
```dart
// lib/services/adb_service.dart
import 'dart:io';
import 'dart:convert';

class AdbService {
  final String _adbPath;

  AdbService(this._adbPath);

  /// Run ADB command targeting a specific device
  Future<ProcessResult> run(String serial, List<String> args, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final fullArgs = ['-s', serial, ...args];
    return Process.run(_adbPath, fullArgs, stdoutEncoding: utf8);
  }

  /// Run ADB command that returns binary data (screenshots)
  Future<List<int>> runBinary(String serial, List<String> args) async {
    final fullArgs = ['-s', serial, ...args];
    final process = await Process.start(_adbPath, fullArgs);
    final bytes = await process.stdout.fold<List<int>>(
      [],
      (prev, chunk) => prev..addAll(chunk),
    );
    await process.exitCode;
    return bytes;
  }

  /// Parse 'adb devices' output
  Future<List<AdbDevice>> listDevices() async {
    final result = await Process.run(_adbPath, ['devices']);
    final lines = (result.stdout as String).split('\n');
    return lines
        .skip(1) // skip header
        .where((l) => l.trim().isNotEmpty)
        .map((line) {
          final parts = line.split(RegExp(r'\s+'));
          return AdbDevice(
            serial: parts[0],
            status: parts.length > 1 ? parts[1] : 'unknown',
            isEmulator: parts[0].startsWith('emulator-'),
            isWifi: parts[0].contains(':'),
          );
        })
        .toList();
  }
}
```

### Pattern 4: UI Tree XML Parsing with Indexed Elements

**What:** Parse uiautomator XML dump, assign stable sequential indices to each visible element.
**When to use:** UI-02, UI-04, UI-05 requirements.
**Example:**
```dart
// lib/services/ui_tree_service.dart
import 'dart:convert';
import 'package:xml/xml.dart'; // add xml package to pubspec

class UiTreeService {
  final AdbService _adb;

  /// Dump and parse UI tree with element indices
  Future<UiTree> getUiTree(String serial, {UiTreeFilter? filter}) async {
    // Use /dev/tty to dump directly to stdout
    final result = await _adb.run(serial, [
      'exec-out', 'uiautomator', 'dump', '/dev/tty',
    ]);
    // Strip trailing "UI hierchary dumped to: /dev/tty" message
    var xml = (result.stdout as String)
        .replaceAll('UI hierchary dumped to: /dev/tty', '')
        .trim();

    final doc = XmlDocument.parse(xml);
    final nodes = <UiNode>[];
    var index = 0;

    for (final element in doc.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'node') continue;
      final bounds = element.getAttribute('bounds') ?? '';
      final text = element.getAttribute('text') ?? '';
      final className = element.getAttribute('class') ?? '';
      final resourceId = element.getAttribute('resource-id') ?? '';
      final contentDesc = element.getAttribute('content-desc') ?? '';
      final visible = element.getAttribute('visible-to-user');

      final node = UiNode(
        index: index++,
        text: text,
        className: className,
        resourceId: resourceId,
        contentDesc: contentDesc,
        bounds: _parseBounds(bounds),
        visible: visible != 'false',
      );

      // Apply filter if provided
      if (filter != null && !filter.matches(node)) continue;
      nodes.add(node);
    }

    return UiTree(nodes: nodes);
  }

  /// Parse bounds format "[left,top][right,bottom]"
  Rect _parseBounds(String bounds) {
    final regex = RegExp(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]');
    final match = regex.firstMatch(bounds);
    if (match == null) return Rect.zero;
    return Rect(
      left: int.parse(match.group(1)!),
      top: int.parse(match.group(2)!),
      right: int.parse(match.group(3)!),
      bottom: int.parse(match.group(4)!),
    );
  }
}
```

### Anti-Patterns to Avoid

- **setState anywhere:** Project mandates rxdart. Use BehaviorSubject + ValueStreamBuilder everywhere. No StatefulWidget with setState.
- **Binding HTTP server to 0.0.0.0:** Always use `InternetAddress.loopbackIPv4`. Never `InternetAddress.anyIPv4`.
- **Writing screenshots to disk:** Pipe ADB binary output directly to base64 in memory. No temp files.
- **Hardcoding ADB path:** Use `process_run`'s `which('adb')` or allow user configuration. ADB location varies by platform.
- **Synchronous ADB calls blocking UI:** All ADB operations must be async. The shelf server runs in the same isolate as Flutter; blocking calls freeze the UI.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP server with routing | Custom dart:io request parser | shelf + shelf_router | Routing, middleware, error handling, content-type negotiation are all solved |
| XML parsing | Regex-based XML extraction | `xml` package (pub.dev) | UIAutomator XML has nested nodes, attributes, special chars. Regex will break. |
| ADB binary discovery | Hardcoded paths per OS | process_run `which()` or env lookup | ADB can be in ~/Android/Sdk, /usr/lib/android-sdk, or custom paths |
| JSON serialization | Manual Map construction | `dart:convert` jsonEncode/jsonDecode | Built-in, handles escaping, nested objects |
| Base64 encoding | Custom encoder | `dart:convert` base64Encode | Built-in, handles padding, standard RFC 4648 |
| Device polling timer | Manual Timer + stream construction | rxdart `Rx.timer` / `Stream.periodic` + switchMap | Handles subscription lifecycle, cancellation, error recovery |

**Key insight:** The ADB command set covers 100% of the required device interactions. There is zero need for Appium, WebDriverAgent, or any third-party automation framework for Android in this phase.

## Common Pitfalls

### Pitfall 1: ADB Screenshot Binary Corruption via `adb shell`

**What goes wrong:** Using `adb shell screencap -p` instead of `adb exec-out screencap -p` produces corrupted PNG data because the PTY layer converts `\n` (0x0A) bytes to `\r\n` (0x0D 0x0A), corrupting the binary PNG stream.
**Why it happens:** `adb shell` allocates a PTY on the device, which does line-ending translation on all output including binary data.
**How to avoid:** Always use `adb exec-out screencap -p` which bypasses the PTY. Requires ADB shell v2 protocol (Android 5.0+).
**Warning signs:** Screenshots fail to decode, intermittent image corruption, PNG data contains unexpected 0x0D bytes.

### Pitfall 2: uiautomator dump Fails on Animated Screens

**What goes wrong:** `adb shell uiautomator dump` returns "ERROR: could not get idle state" when the screen has animations, transitions, or live-updating content. This blocks UI tree extraction entirely.
**Why it happens:** uiautomator waits for the UI to reach an "idle" state before dumping. Animations never reach idle.
**How to avoid:** (1) Retry with a short delay. (2) Disable animations on device: `adb shell settings put global window_animation_scale 0` and similar. (3) Accept partial failures and return the last successful dump.
**Warning signs:** UI tree returns empty or error for apps with shimmer, loading spinners, or auto-scrolling content.

### Pitfall 3: ADB WiFi Connection Drops After Screen Lock

**What goes wrong:** WiFi ADB connections disconnect when the device screen locks, enters deep sleep, or changes networks. The device disappears from `adb devices` silently.
**Why it happens:** Android disables wireless debugging after inactivity to save power and for security.
**How to avoid:** (1) Poll `adb devices` periodically (every 5 seconds) to detect disconnections. (2) Implement auto-reconnect with `adb connect IP:PORT`. (3) Show clear connection status in the Hub UI. (4) Prefer USB connections for reliability.
**Warning signs:** Device shows "offline" status intermittently. Commands fail with "device not found" after idle periods.

### Pitfall 4: Special Characters in `adb shell input text`

**What goes wrong:** Characters like spaces, quotes, ampersands, parentheses, and Unicode break `adb shell input text`. The shell interprets them before the input command sees them.
**Why it happens:** The text passes through two shells (host + device). Special characters are interpreted at each level.
**How to avoid:** (1) Escape special characters with `%s` encoding. (2) For complex text, use `adb shell input keyboard text` or inject via ADB broadcast. (3) As fallback, use clipboard: `adb shell input keyevent 279` (paste) after setting clipboard content.
**Warning signs:** Typed text appears truncated, garbled, or missing characters.

### Pitfall 5: Flutter Desktop Window Flash on Windows (Process Spawn)

**What goes wrong:** On Windows, each `Process.start()` call for ADB commands briefly flashes a cmd.exe window.
**Why it happens:** Windows creates a visible console window for each child process by default. Dart's Process.start does not expose `CREATE_NO_WINDOW` flags.
**How to avoid:** (1) Use `runInShell: true` which may help on some Windows versions. (2) For Phase 1 on Linux/macOS this is not an issue. (3) Can be addressed with a platform channel later for Windows polish.
**Warning signs:** Users on Windows report flickering black windows during device operations.

### Pitfall 6: ADB Path Not Found on Clean Installs

**What goes wrong:** `adb` is not in PATH on many developer machines. Android Studio installs ADB to SDK-specific paths that vary by OS and installation method.
**Why it happens:** Unlike `git` or `flutter`, ADB is not typically in the system PATH unless manually added.
**How to avoid:** (1) Check ANDROID_HOME / ANDROID_SDK_ROOT environment variables. (2) Check common paths: `~/Android/Sdk/platform-tools/adb`, `/usr/lib/android-sdk/platform-tools/adb`. (3) On macOS also check `~/Library/Android/sdk/platform-tools/adb`. (4) Show clear error in Hub UI if ADB is not found with setup instructions.
**Warning signs:** "adb: command not found" on first launch.

## Code Examples

### ADB Device Metadata Collection

```dart
// Collect full device metadata for DEV-01, DEV-06
Future<DeviceMetadata> getDeviceMetadata(String serial) async {
  final futures = await Future.wait([
    _adb.run(serial, ['shell', 'getprop', 'ro.product.model']),
    _adb.run(serial, ['shell', 'getprop', 'ro.product.manufacturer']),
    _adb.run(serial, ['shell', 'getprop', 'ro.build.version.release']),
    _adb.run(serial, ['shell', 'getprop', 'ro.build.version.sdk']),
    _adb.run(serial, ['shell', 'wm', 'size']),
    _adb.run(serial, ['shell', 'dumpsys', 'battery']),
  ]);

  final screenSize = _parseScreenSize(futures[4].stdout as String);
  final battery = _parseBattery(futures[5].stdout as String);

  return DeviceMetadata(
    model: (futures[0].stdout as String).trim(),
    manufacturer: (futures[1].stdout as String).trim(),
    osVersion: (futures[2].stdout as String).trim(),
    sdkVersion: int.tryParse((futures[3].stdout as String).trim()) ?? 0,
    screenWidth: screenSize.width,
    screenHeight: screenSize.height,
    batteryLevel: battery.level,
    batteryStatus: battery.status,
  );
}

// Parse "Physical size: 1080x2400"
({int width, int height}) _parseScreenSize(String output) {
  final match = RegExp(r'(\d+)x(\d+)').firstMatch(output);
  return (
    width: int.tryParse(match?.group(1) ?? '') ?? 0,
    height: int.tryParse(match?.group(2) ?? '') ?? 0,
  );
}
```

### Screenshot Capture (Binary-Safe)

```dart
// DEV UI-01: Capture screenshot as base64 PNG
Future<String> captureScreenshot(String serial) async {
  // MUST use exec-out (not shell) to avoid PTY binary corruption
  final bytes = await _adb.runBinary(serial, [
    'exec-out', 'screencap', '-p',
  ]);
  return base64Encode(bytes);
}
```

### All Device Action Commands

```dart
// ACT-01: Tap at coordinates
Future<void> tap(String serial, int x, int y) async {
  await _adb.run(serial, ['shell', 'input', 'tap', '$x', '$y']);
}

// ACT-02: Tap element by index (resolve from UI tree)
Future<void> tapElement(String serial, int index) async {
  final tree = await _uiTreeService.getUiTree(serial);
  final node = tree.nodes.firstWhere((n) => n.index == index);
  final center = node.bounds.center;
  await tap(serial, center.x, center.y);
}

// ACT-03: Type text
Future<void> typeText(String serial, String text) async {
  // Escape special characters for shell
  final escaped = text.replaceAll(' ', '%s')
      .replaceAll('&', '\\&')
      .replaceAll('<', '\\<')
      .replaceAll('>', '\\>')
      .replaceAll("'", "\\'")
      .replaceAll('"', '\\"');
  await _adb.run(serial, ['shell', 'input', 'text', escaped]);
}

// ACT-04: Swipe
Future<void> swipe(String serial, int x1, int y1, int x2, int y2, {
  int durationMs = 300,
}) async {
  await _adb.run(serial, [
    'shell', 'input', 'swipe',
    '$x1', '$y1', '$x2', '$y2', '$durationMs',
  ]);
}

// ACT-05: Press key
Future<void> pressKey(String serial, int keyCode) async {
  await _adb.run(serial, ['shell', 'input', 'keyevent', '$keyCode']);
}

// ACT-06: Go home
Future<void> goHome(String serial) async {
  await pressKey(serial, 3); // KEYCODE_HOME
}

// ACT-07: Launch app
Future<void> launchApp(String serial, String packageName) async {
  await _adb.run(serial, [
    'shell', 'monkey', '-p', packageName,
    '-c', 'android.intent.category.LAUNCHER', '1',
  ]);
}

// ACT-08: Terminate app
Future<void> terminateApp(String serial, String packageName) async {
  await _adb.run(serial, ['shell', 'am', 'force-stop', packageName]);
}

// ACT-09: Open URL
Future<void> openUrl(String serial, String url) async {
  await _adb.run(serial, [
    'shell', 'am', 'start', '-a', 'android.intent.action.VIEW', '-d', url,
  ]);
}

// ACT-10: Long press (swipe with zero movement, long duration)
Future<void> longPress(String serial, int x, int y, {
  int durationMs = 1500,
}) async {
  await _adb.run(serial, [
    'shell', 'input', 'swipe', '$x', '$y', '$x', '$y', '$durationMs',
  ]);
}
```

### WiFi ADB Connection (DEV-03)

```dart
// WiFi ADB connection workflow
Future<bool> connectWifi(String ipPort) async {
  final result = await Process.run(_adbPath, ['connect', ipPort]);
  final output = (result.stdout as String).trim();
  return output.contains('connected') || output.contains('already connected');
}

// Legacy workflow: USB-first then switch to WiFi
Future<bool> enableWifiAdb(String usbSerial, int port) async {
  // Step 1: Put device into TCP/IP mode
  await _adb.run(usbSerial, ['tcpip', '$port']);
  await Future.delayed(const Duration(seconds: 2));

  // Step 2: Get device IP
  final ipResult = await _adb.run(usbSerial, [
    'shell', 'ip', 'route', 'show', 'dev', 'wlan0',
  ]);
  final ip = _extractIp(ipResult.stdout as String);
  if (ip == null) return false;

  // Step 3: Connect via WiFi
  return connectWifi('$ip:$port');
}
```

### ADB Key Codes Reference

```dart
// lib/core/constants.dart
class AdbKeyCodes {
  static const int home = 3;
  static const int back = 4;
  static const int call = 5;
  static const int endCall = 6;
  static const int volumeUp = 24;
  static const int volumeDown = 25;
  static const int power = 26;
  static const int camera = 27;
  static const int enter = 66;
  static const int backspace = 67;
  static const int delete = 112;
  static const int menu = 82;
  static const int search = 84;
  static const int tab = 61;
  static const int escape = 111;
  static const int recentApps = 187;
  static const int mute = 164;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `adb shell screencap -p` | `adb exec-out screencap -p` | ADB v2 protocol (Android 5.0+) | Avoids binary corruption from PTY |
| `uiautomator dump /sdcard/dump.xml` + `adb pull` | `adb exec-out uiautomator dump /dev/tty` | Works on modern ADB | Single command, no temp file on device |
| `adb tcpip 5555` + `adb connect` | `adb pair` + `adb connect` (Android 11+) | 2020 | TLS encrypted, no USB needed for initial pairing |
| setState in Flutter | rxdart BehaviorSubject | Project convention | Reactive, testable, separates business logic from UI |
| Provider/BLoC | rxdart direct | Project preference | Simpler, fewer abstractions, developer familiarity |

**Deprecated/outdated:**
- `instruments -s devices` (iOS): Replaced by `xcrun xctrace list devices` -- not relevant for Phase 1 (Android only)
- `adb forward` for screenshot transfer: Unnecessary with `exec-out` piping directly to stdout
- gorilla/websocket (Go): Not relevant for Phase 1 (Flutter/Dart only)

## Open Questions

1. **Concurrent ADB command limit**
   - What we know: ADB server can handle multiple parallel commands but may bottleneck around 5 simultaneous connections
   - What's unclear: Exact concurrency limit varies by ADB server version and OS
   - Recommendation: Start with serial execution per device, add concurrency pool if performance demands it

2. **shelf server in Flutter isolate vs separate isolate**
   - What we know: shelf can run in the main isolate alongside Flutter. Heavy screenshot processing might block the event loop.
   - What's unclear: Whether screenshot base64 encoding of large (4K device) images will cause UI jank
   - Recommendation: Start in main isolate. If screenshots cause jank, move ADB binary operations to a compute isolate.

3. **xml package for uiautomator dump**
   - What we know: The `xml` package on pub.dev parses XML. uiautomator output is well-formed XML.
   - What's unclear: Performance on very large UI trees (100+ nodes)
   - Recommendation: Use `xml` package. It handles the standard uiautomator XML format. Add `xml: ^6.0.0` to pubspec.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | Hub app | Yes | 3.41.5 (stable) | -- |
| Dart SDK | Language runtime | Yes | 3.11.3 | -- |
| ADB | All Android automation | Yes | 34.0.4 | -- |
| Linux toolchain (clang, cmake, ninja, pkg-config) | Flutter Desktop Linux build | Yes | clang 18.1.3, cmake 3.28.3, ninja 1.11.1 | -- |
| Android device (for testing) | Integration testing | Yes | CPH2467 (Android 15, WiFi) | Emulator via Android SDK |
| Android Emulator | Testing without physical device | Yes | 36.3.10.0 | -- |
| git | Version control | Yes | 2.43.0 | -- |

**Missing dependencies with no fallback:** None -- all required tools are installed and verified.

**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | N/A -- CLAUDE.md explicitly states "never waste the time for creating tests" |
| Config file | N/A |
| Quick run command | Manual curl testing against HTTP API |
| Full suite command | Manual end-to-end verification with connected device |

### Phase Requirements -> Validation Map

Per CLAUDE.md, no automated tests. Validation is manual:

| Req ID | Behavior | Validation Method |
|--------|----------|-------------------|
| DEV-01 | List devices | `curl localhost:8686/api/v1/devices` returns JSON array |
| UI-01 | Screenshot | `curl localhost:8686/api/v1/devices/{id}/screenshot` returns base64 PNG |
| UI-02 | UI tree | `curl localhost:8686/api/v1/devices/{id}/ui-tree` returns indexed JSON |
| ACT-01 | Tap | `curl -X POST localhost:8686/api/v1/devices/{id}/tap -d '{"x":540,"y":1200}'` |
| HUB-01 | Device list UI | Launch Flutter app, verify device cards appear |
| HUB-07 | Cross-platform | `flutter run -d linux` succeeds |

### Wave 0 Gaps
None -- no test infrastructure needed per project constraints.

## HTTP API Contract

The following API contract is critical because Phase 2's MCP server will be a stateless client of this API.

### Endpoints

| Method | Path | Purpose | Request Body | Response |
|--------|------|---------|-------------|----------|
| GET | /health | Server health check | -- | `{"status": "ok"}` |
| GET | /api/v1/devices | List all devices | -- | `[{device objects}]` |
| GET | /api/v1/devices/:id | Get single device | -- | `{device object}` |
| GET | /api/v1/devices/:id/screenshot | Capture screenshot | -- | `{"screenshot": "base64...", "width": N, "height": N}` |
| GET | /api/v1/devices/:id/ui-tree | Get UI tree | Query: `?text=regex&visible=true` | `{"nodes": [{indexed nodes}]}` |
| POST | /api/v1/devices/:id/tap | Tap coordinates or element | `{"x": N, "y": N}` or `{"index": N}` | `{"success": true}` |
| POST | /api/v1/devices/:id/swipe | Swipe gesture | `{"x1": N, "y1": N, "x2": N, "y2": N, "duration": N}` | `{"success": true}` |
| POST | /api/v1/devices/:id/type | Type text | `{"text": "string"}` | `{"success": true}` |
| POST | /api/v1/devices/:id/keyevent | Press key | `{"keyCode": N}` | `{"success": true}` |
| POST | /api/v1/devices/:id/launch | Launch app | `{"package": "com.app"}` | `{"success": true}` |
| POST | /api/v1/devices/:id/terminate | Kill app | `{"package": "com.app"}` | `{"success": true}` |
| POST | /api/v1/devices/:id/open-url | Open URL/deep link | `{"url": "https://..."}` | `{"success": true}` |
| POST | /api/v1/devices/:id/gesture | Advanced gesture | `{"type": "long_press", "x": N, "y": N, "duration": N}` | `{"success": true}` |
| POST | /api/v1/devices/:id/bridge/start | Start bridge | -- | `{"status": "active"}` |
| POST | /api/v1/devices/:id/bridge/stop | Stop bridge | -- | `{"status": "stopped"}` |
| POST | /api/v1/devices/connect-wifi | WiFi ADB connect | `{"address": "IP:PORT"}` | `{"success": true, "serial": "..."}` |

### Device Object Schema

```json
{
  "id": "serial-string",
  "serial": "abc123",
  "model": "Pixel 8",
  "manufacturer": "Google",
  "osVersion": "15",
  "sdkVersion": 35,
  "screenWidth": 1080,
  "screenHeight": 2400,
  "batteryLevel": 85,
  "batteryStatus": "charging",
  "connectionType": "usb|wifi|emulator",
  "status": "connected|offline|bridged",
  "bridgeActive": false
}
```

## Sources

### Primary (HIGH confidence)
- [shelf pub.dev](https://pub.dev/packages/shelf) - v1.4.2, Dart team maintained
- [shelf_router pub.dev](https://pub.dev/packages/shelf_router) - v1.1.4, Dart team maintained
- [rxdart pub.dev](https://pub.dev/packages/rxdart) - v0.28.0, ReactiveX maintained
- [rxdart_flutter pub.dev](https://pub.dev/packages/rxdart_flutter) - v0.0.2, officially maintained
- [window_manager pub.dev](https://pub.dev/packages/window_manager) - v0.5.1
- [process_run pub.dev](https://pub.dev/packages/process_run) - v1.3.1+1
- [Android ADB official docs](https://developer.android.com/tools/adb) - Device communication reference
- [ADB screencap binary capture guide](https://www.repeato.app/efficiently-capturing-screenshots-on-android-devices-via-adb/) - exec-out vs shell comparison
- [Dart HttpServer API](https://api.flutter.dev/flutter/dart-io/HttpServer-class.html) - dart:io server reference
- [Dart Process.start API](https://api.flutter.dev/flutter/dart-io/Process/start.html) - Process execution reference

### Secondary (MEDIUM confidence)
- [Building REST APIs with Dart and Shelf (2025)](https://dev.to/andrewjames/building-rest-apis-with-dart-and-shelf-2025-guide-4bii) - shelf server patterns
- [rxdart BehaviorSubject patterns](https://maxim-gorin.medium.com/reactive-programming-with-rxdart-comprehensive-guide-1912006db5ed) - State management approach
- [ADB keyevent codes complete list](https://gist.github.com/arjunv/2bbcca9a1a1c127749f8dcb6d36fb0bc) - All key codes reference
- [ADB advanced input commands](https://adb-shell.com/android/input/) - Swipe, long press, multi-touch
- [Extracting Android layout via ADB](https://www.repeato.app/extracting-layout-and-view-information-via-adb/) - uiautomator dump patterns
- [Flutter Linux desktop setup](https://docs.flutter.dev/platform-integration/linux/setup) - Build dependencies

### Tertiary (LOW confidence)
- None -- all findings verified against official sources.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all packages verified on pub.dev with exact versions, Flutter/ADB verified installed locally
- Architecture: HIGH -- shelf embedded server in Flutter desktop is a documented pattern; rxdart BehaviorSubject is battle-tested
- ADB commands: HIGH -- every command verified against official Android docs and community references
- Pitfalls: HIGH -- ADB screenshot corruption and uiautomator idle failure are well-documented, reproducible issues

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (stable domain -- ADB and shelf change infrequently)
