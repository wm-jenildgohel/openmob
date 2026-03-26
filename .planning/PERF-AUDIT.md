# OpenMob Performance Audit

Audited: 2026-03-26
Scope: All service files, UI screens, API routes, and Rust bridge source

---

## PERF-01: Process.runSync blocks UI thread in AdbService.adbPath

- **FILE:LINE** `openmob_hub/lib/services/adb_service.dart:23`
- **IMPACT:** HIGH
- **CURRENT:** `adbPath` getter uses `Process.runSync('which', ['adb'])` on the first call. This getter is called by every ADB operation. The first ADB call on each app session freezes the UI for 50-200ms while spawning a synchronous process. Since `adbPath` is `await`ed (it returns a `Future`), the `Process.runSync` inside it is particularly deceptive -- it blocks the main isolate despite appearing async.
- **FIX:** Replace `Process.runSync` with `Process.run` (async). The method already returns `Future<String>`, so the change is trivial:
```dart
// BEFORE (line 23-33):
final result = Process.runSync(
  Platform.isWindows ? 'where' : 'which',
  ['adb'],
);
// AFTER:
final result = await Process.run(
  Platform.isWindows ? 'where' : 'which',
  ['adb'],
);
```
- **WHY:** Eliminates a UI freeze on first device operation. The adb path is cached after first resolution so this only fires once, but it fires during the first `refreshDevices()` call which runs right after startup -- exactly when users are looking at the app.

---

## PERF-02: Sequential device enrichment -- 6 ADB calls per device, devices processed in series

- **FILE:LINE** `openmob_hub/lib/services/device_manager.dart:37-49`
- **IMPACT:** HIGH
- **CURRENT:** The `refreshDevices()` loop iterates over each raw device and calls `_enrichDevice()` sequentially. `_enrichDevice` itself correctly parallelizes its 6 ADB calls with `Future.wait`, but if you have 3 devices, enrichment runs 3 x sequentially = ~3 seconds total (each device takes ~1s). With 5-second polling, the system spends 60% of its time enriching devices.
- **FIX:** Parallelize across devices:
```dart
// BEFORE (line 37-49):
for (final raw in rawDevices) {
  if (raw.status == 'device') {
    try {
      final device = await _enrichDevice(raw.serial);
      enriched.add(device);
    } catch (_) { ... }
  } else { ... }
}

// AFTER:
final futures = rawDevices.map((raw) async {
  if (raw.status == 'device') {
    try {
      return await _enrichDevice(raw.serial);
    } catch (_) {
      return Device.fromAdb(serial: raw.serial, status: raw.status);
    }
  }
  return Device.fromAdb(serial: raw.serial, status: raw.status);
}).toList();
enriched.addAll(await Future.wait(futures));
```
- **WHY:** With 3 connected devices, refresh drops from ~3s to ~1s. The user sees device info update faster and the device list feels responsive rather than stale.

---

## PERF-03: Device enrichment runs every 5s even when nothing changes

- **FILE:LINE** `openmob_hub/lib/main.dart:158` and `openmob_hub/lib/services/device_manager.dart:33-70`
- **IMPACT:** HIGH
- **CURRENT:** Every 5 seconds, `refreshDevices()` calls `adb devices`, then runs 6 `getprop`/`wm`/`dumpsys` commands per device. For a stable USB-connected device, model/manufacturer/OS version/screen size never change. Battery level changes slowly. This generates ~7 process spawns per device per poll = 42 processes per minute for a single device.
- **FIX:** Split enrichment into two tiers:
  1. **Fast poll (every 5s):** Only call `adb devices` to detect connect/disconnect. Compare serial list with previous list. Only run full enrichment for NEW serials.
  2. **Slow poll (every 60s):** Refresh battery level for already-enriched devices.
  Cache enriched device data in a `Map<String, Device>` keyed by serial and reuse across poll cycles.
```dart
final _enrichCache = <String, Device>{};

Future<void> refreshDevices() async {
  final rawDevices = await _adb.listRawDevices();
  final currentSerials = rawDevices
      .where((r) => r.status == 'device')
      .map((r) => r.serial)
      .toSet();

  // Only enrich new devices
  final newSerials = currentSerials.difference(_enrichCache.keys.toSet());
  for (final serial in newSerials) {
    try {
      _enrichCache[serial] = await _enrichDevice(serial);
    } catch (_) {}
  }

  // Remove disconnected devices from cache
  _enrichCache.removeWhere((k, _) => !currentSerials.contains(k));

  // Build final list from cache + non-device entries
  final enriched = <Device>[
    ..._enrichCache.values,
    ...rawDevices
        .where((r) => r.status != 'device')
        .map((r) => Device.fromAdb(serial: r.serial, status: r.status)),
  ];
  // ... merge iOS, preserve bridge state ...
}
```
- **WHY:** Reduces steady-state process spawns from ~42/min to ~2/min (just `adb devices`). CPU usage drops dramatically. ADB server contention is eliminated, making on-demand operations (screenshots, UI tree) faster.

---

## PERF-04: capturePreview returns full-resolution PNG -- no actual downscaling

- **FILE:LINE** `openmob_hub/lib/services/screenshot_service.dart:47-63`
- **IMPACT:** HIGH
- **CURRENT:** `capturePreview()` has a `maxWidth` parameter (default 480) but completely ignores it. It calls `adb exec-out screencap -p` which returns a full-resolution PNG (typically 1080x1920 = 3-6 MB). This raw PNG is then passed to `Image.memory()` every 500ms in the live preview. Flutter decodes the full image, allocates a full-res texture, then scales it down for display. Per frame: ~5MB allocation, ~5MB decode, ~5MB GPU upload -- 10 times per second worst case.
- **FIX:** Use ADB's built-in screencap width/height scaling, or pipe through a resize. ADB does not natively support resolution arguments, but you can pipe through `toybox convert` on-device or reduce on the Dart side:
```dart
Future<Uint8List> capturePreview(String serial, {int maxWidth = 480}) async {
  final bytes = await _adb.runBinary(
    serial,
    ['exec-out', 'screencap', '-p'],
  );

  // Decode and resize in memory using dart:ui
  final codec = await ui.instantiateImageCodec(
    Uint8List.fromList(bytes),
    targetWidth: maxWidth,
  );
  final frame = await codec.getNextFrame();
  final resized = await frame.image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  codec.dispose();
  frame.image.dispose();
  return resized!.buffer.asUint8List();
}
```
Alternatively, run the resize in a separate isolate with `compute()` to keep the main thread completely free.
- **WHY:** A 480px-wide PNG is ~100-200KB vs 3-6MB. That is a 20-30x reduction in memory allocation per frame. The live preview will feel smoother, scrolling won't hitch, and the app won't pressure the GC.

---

## PERF-05: Live preview polls at 500ms (2 FPS) regardless of screenshot capture duration

- **FILE:LINE** `openmob_hub/lib/ui/widgets/live_preview.dart:25`
- **IMPACT:** MEDIUM
- **CURRENT:** `Timer.periodic(500ms)` fires `_fetch()` every 500ms. `_fetch()` guards against re-entry with `_loading.value`, but a screenshot capture typically takes 300-800ms over USB. If capture takes 600ms, the timer fires during the capture, gets skipped, then fires again immediately after capture completes -- creating a burst pattern. The timer does not account for the time already spent capturing, so effective frame rate is unpredictable (0.5-2 FPS).
- **FIX:** Replace periodic timer with a recursive delay that fires AFTER the previous capture completes:
```dart
void start() {
  _fetch(); // initial fetch
}

Future<void> _fetch() async {
  if (_disposed || _loading.isClosed) return;
  if (_loading.value) return;
  _loading.add(true);
  try {
    final bytes = await screenshotService.capturePreview(deviceId);
    if (_disposed) return;
    _image.add(bytes);
  } catch (_) {}
  finally {
    if (!_disposed) {
      _loading.add(false);
      // Wait a fixed gap AFTER capture completes
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_disposed) _fetch();
      });
    }
  }
}
```
- **WHY:** Provides consistent ~2 FPS with no bunching. Eliminates the scenario where two captures overlap or fire back-to-back with zero gap.

---

## PERF-06: Process.runSync blocks UI thread in ProcessManager during construction

- **FILE:LINE** `openmob_hub/lib/services/process_manager.dart:52-64`
- **IMPACT:** MEDIUM
- **CURRENT:** `_detectAgents()` calls `Process.runSync('which', ['claude'])`, `Process.runSync('which', ['codex'])`, `Process.runSync('which', ['gemini'])` -- three synchronous process spawns. This is called from `_warmCache()` via `Future(() => _detectAgents())`, but `Future(() => ...)` runs on the SAME isolate (it just defers to the next microtask). It does NOT run on a background isolate. The three `Process.runSync` calls block the main thread for ~150-300ms total.
- **FIX:** Use `Process.run` (async) or run in `compute()`:
```dart
Future<List<String>> _detectAgents() async {
  final agents = <String>[];
  final results = await Future.wait([
    Process.run(Platform.isWindows ? 'where' : 'which', ['claude']),
    Process.run(Platform.isWindows ? 'where' : 'which', ['codex']),
    Process.run(Platform.isWindows ? 'where' : 'which', ['gemini']),
  ]);
  for (var i = 0; i < results.length; i++) {
    if (results[i].exitCode == 0) {
      agents.add(['claude', 'codex', 'gemini'][i]);
    }
  }
  return agents;
}
```
- **WHY:** The 150-300ms saved happens during startup, right when the user is waiting for the UI to appear. Combined with PERF-01, startup becomes ~300-500ms snappier.

---

## PERF-07: Process.runSync in _terminalEmulator and _bridgeBinary (ProcessManager)

- **FILE:LINE** `openmob_hub/lib/services/process_manager.dart:237-306`
- **IMPACT:** MEDIUM
- **CURRENT:** `_bridgeBinary` getter (line 237) and `_terminalEmulator` getter (line 284) both use `Process.runSync('which'/'where', ...)` to probe for binaries. `_bridgeBinary` can call `Process.runSync` up to 2 times (once for PATH lookup, once for project build check). `_terminalEmulator` tries up to 8 terminals sequentially with `Process.runSync`. Although these are called from `_warmCache`, the same `Future(() => ...)` problem from PERF-06 applies -- they run on the main isolate.
- **FIX:** Convert both getters to async methods using `Process.run`, and await them in `_warmCache`. Since `_warmCache` already uses `Future.wait`, just make the individual lookups truly async:
```dart
Future<String?> _findBridgeBinary() async { ... use Process.run ... }
Future<String?> _findTerminalEmulator() async { ... use Process.run ... }
```
- **WHY:** Prevents 8 synchronous process spawns (worst case for terminal detection on Linux) from blocking the UI thread at startup.

---

## PERF-08: Process.runSync in SystemCheckService._checkAiBridge

- **FILE:LINE** `openmob_hub/lib/services/system_check_service.dart:525-538`
- **IMPACT:** MEDIUM
- **CURRENT:** `_checkAiBridge()` uses `Process.runSync('which', ['aibridge'])` at line 525. This is called from `checkAll()` which is called from `autoSetupService.runAutoSetup()` in the background init. Since `runAutoSetup` runs on the main isolate, this `runSync` freezes the UI.
- **FIX:** Replace with async `Process.run`:
```dart
final result = await Process.run(
  Platform.isWindows ? 'where' : 'which',
  ['aibridge'],
);
```
- **WHY:** Consistent with making all process calls async. This one fires shortly after startup during auto-setup.

---

## PERF-09: Process.runSync in SystemCheckService._checkAdb (line 80)

- **FILE:LINE** `openmob_hub/lib/services/system_check_service.dart:80-84`
- **IMPACT:** MEDIUM
- **CURRENT:** After successfully running `adb version` asynchronously, the code calls `Process.runSync('which', ['adb'])` to get the system path. This synchronous call is redundant -- `adb version` already proved `adb` is on PATH, so `which adb` will succeed.
- **FIX:** Either cache the result from the async `Process.run('adb', ['version'])` call, or replace `runSync` with `Process.run`:
```dart
final whichResult = await Process.run(
  Platform.isWindows ? 'where' : 'which',
  ['adb'],
);
```
- **WHY:** Another main-thread freeze during auto-setup. Every `Process.runSync` is a 30-100ms jank opportunity.

---

## PERF-10: SystemCheckService.checkAll runs tool checks sequentially

- **FILE:LINE** `openmob_hub/lib/services/system_check_service.dart:35-48`
- **IMPACT:** MEDIUM
- **CURRENT:** `checkAll()` awaits each tool check one-by-one:
```dart
results.add(await _checkAdb());
results.add(await _checkScrcpy());
results.add(await _checkMcpServer());
results.add(await _checkAiBridge());
```
Each check spawns at least one process. Total wall time: 4-8 tool checks x 100-300ms each = 400ms-2.4s.
- **FIX:** Run all checks in parallel:
```dart
final checks = await Future.wait([
  _checkAdb(),
  _checkScrcpy(),
  _checkMcpServer(),
  _checkAiBridge(),
  if (Platform.isMacOS) _checkIdb(),
]);
_tools.add(checks);
```
- **WHY:** Startup is blocked on auto-setup which calls `checkAll()`. Parallelizing cuts 400ms-2.4s down to ~300ms (limited by slowest single check).

---

## PERF-11: LogService creates a new list on every addLine call

- **FILE:LINE** `openmob_hub/lib/services/log_service.dart:28-40`
- **IMPACT:** MEDIUM
- **CURRENT:** Every `addLine` call creates a new list: `final updated = [entry, ..._logs.value]`. This copies up to 1000 entries into a new list. With MCP stdout/stderr logging, bridge logging, and device polling, `addLine` can fire 10-50 times per second. That is 10-50 list copies of up to 1000 items per second, creating significant GC pressure.
- **FIX:** Use a fixed-capacity ring buffer or at minimum avoid the spread operator:
```dart
void addLine(String source, String message, {LogLevel level = LogLevel.info}) {
  final entry = LogEntry(
    timestamp: DateTime.now(),
    source: source,
    message: message,
    level: level,
  );
  final current = _logs.value;
  final updated = List<LogEntry>.of(current, growable: true);
  updated.insert(0, entry);
  if (updated.length > _maxEntries) {
    updated.removeRange(_maxEntries, updated.length);
  }
  _logs.add(updated);
}
```
Better yet, batch log updates using a debounced approach -- accumulate entries in a buffer and flush to the BehaviorSubject every 100ms.
- **WHY:** Reduces GC pressure from O(n) list copies on every log line to O(1) inserts. UI jank from GC pauses decreases noticeably when MCP/bridge processes are active and chatty.

---

## PERF-12: Screenshot endpoint returns full base64-encoded PNG in JSON

- **FILE:LINE** `openmob_hub/lib/server/routes/device_routes.dart:34-51` and `openmob_hub/lib/services/screenshot_service.dart:19-43`
- **IMPACT:** MEDIUM
- **CURRENT:** The `/screenshot` API endpoint captures a full-resolution PNG (~3-6MB), base64-encodes it (~4-8MB string), then wraps it in a JSON object. The base64 encoding adds 33% overhead and the JSON serialization allocates another copy. Total memory for one screenshot response: original bytes + base64 string + JSON string = ~12-18MB of transient allocations.
- **FIX:**
  1. Return raw PNG bytes with `Content-Type: image/png` instead of base64-in-JSON for the screenshot endpoint. Add width/height as response headers.
  2. If JSON is required (for MCP compatibility), add a `?quality=preview` query param that returns a resized image (480px wide).
```dart
router.get('/<id>/screenshot', (Request request, String id) async {
  final quality = request.url.queryParameters['quality'];
  if (quality == 'preview') {
    final bytes = await ss.capturePreview(device.serial);
    return Response.ok(bytes, headers: {'content-type': 'image/png'});
  }
  // ... existing full-res base64 path for backward compat ...
});
```
- **WHY:** AI agents that need the screenshot for vision models can request the compact preview. The MCP server, which sends screenshots to LLM APIs, benefits most -- a 200KB PNG vs a 6MB PNG saves 5 seconds of upload time per tool call.

---

## PERF-13: ADB adbPath resolved on every command (lock contention on hot path)

- **FILE:LINE** `openmob_hub/lib/services/adb_service.dart:7-8, 42-44`
- **IMPACT:** LOW
- **CURRENT:** Every `run()` call does `final adb = await adbPath;` which checks `_adbPath != null` then returns cached path. This is a Future that must go through the event loop even though the result is already known. During rapid-fire operations (e.g., device enrichment with 6 parallel calls), this creates 6 unnecessary event loop trips.
- **FIX:** Make `adbPath` eagerly resolved once at construction time, stored as a sync field:
```dart
String? _resolvedPath;

/// Call once during initialization
Future<void> init() async {
  _resolvedPath = await _resolveAdbPath();
}

String get adbPath {
  if (_resolvedPath == null) throw StateError('AdbService not initialized');
  return _resolvedPath!;
}
```
- **WHY:** Minor optimization that removes event loop overhead from the hot path. Most noticeable during the 6-way `Future.wait` in `_enrichDevice`.

---

## PERF-14: bridge.rs PTY reader calls block_on inside spawn_blocking

- **FILE:LINE** `openmob_bridge/src/bridge.rs:119-123`
- **IMPACT:** MEDIUM
- **CURRENT:** Inside the `read_handle` (a `spawn_blocking` task), the code calls `handle.block_on(det_inner.process_line(&line_owned))` for every non-empty line of PTY output. `block_on` inside `spawn_blocking` is technically safe but creates contention: it steals a worker thread from tokio's blocking pool to wait on an async lock (`BusyDetector.state` is a `tokio::sync::Mutex`). Under heavy output (e.g., agent writing many lines), this can starve other blocking tasks.
- **FIX:** Use `handle.spawn` instead of `handle.block_on` to fire-and-forget the detector update:
```rust
if let Ok(handle) = tokio::runtime::Handle::try_current() {
    let det_inner = det.clone();
    let line_owned = line.to_string();
    handle.spawn(async move {
        det_inner.process_line(&line_owned).await;
    });
}
```
Or batch lines and send them through a channel to avoid per-line async overhead entirely.
- **WHY:** Prevents blocking pool thread starvation when the AI agent produces rapid output (e.g., code generation). Injection delivery becomes more responsive because the injection loop can acquire the detector lock faster.

---

## PERF-15: InjectionQueue uses Vec::remove(0) -- O(n) dequeue

- **FILE:LINE** `openmob_bridge/src/queue.rs:108`
- **IMPACT:** LOW
- **CURRENT:** `dequeue()` calls `items.remove(0)` which shifts all remaining elements left by one position. With `MAX_QUEUE_SIZE = 100`, this means up to 99 element copies per dequeue.
- **FIX:** Use `VecDeque` instead of `Vec`:
```rust
use std::collections::VecDeque;

pub struct InjectionQueue {
    items: Arc<Mutex<VecDeque<Injection>>>,
}

// dequeue becomes:
pub async fn dequeue(&self) -> Option<Injection> {
    let mut items = self.items.lock().await;
    items.pop_front()
}

// priority insert becomes:
items.push_front(injection); // instead of items.insert(0, injection)
```
- **WHY:** O(1) dequeue vs O(n). With max 100 items, the absolute time savings is small, but this is the correct data structure for a FIFO queue and eliminates unnecessary copying.

---

## PERF-16: No timeout on simctl/idb operations during device refresh

- **FILE:LINE** `openmob_hub/lib/services/device_manager.dart:52-59`
- **IMPACT:** MEDIUM
- **CURRENT:** `_simctl.listSimulators()` has no timeout. If the Xcode toolchain is installed but hung (e.g., Xcode first-launch dialog), this call blocks the entire `refreshDevices()` cycle indefinitely. The 5-second poll timer keeps firing, but each call is blocked waiting for the previous one to complete, creating an ever-growing backlog of pending futures.
- **FIX:** Add a timeout:
```dart
if (_simctl != null) {
  try {
    final simulators = await _simctl.listSimulators()
        .timeout(const Duration(seconds: 5));
    enriched.addAll(simulators);
  } catch (_) {}
}
```
- **WHY:** Prevents a single hung simctl call from blocking all device management. The 5-second timeout matches the poll interval, so at worst one cycle is lost.

---

## PERF-17: No guard against concurrent refreshDevices calls

- **FILE:LINE** `openmob_hub/lib/services/device_manager.dart:33`
- **IMPACT:** MEDIUM
- **CURRENT:** `refreshDevices()` can be called from three sources: the 5-second timer (main.dart:158), the manual refresh button (home_screen.dart:50), and `connectWifi()` (device_manager.dart:158). Nothing prevents two calls from running simultaneously. If the user clicks refresh while the timer fires, both calls run their ADB commands concurrently, doubling the load on the ADB server and potentially interleaving the BehaviorSubject updates in unpredictable order.
- **FIX:** Add a simple lock:
```dart
bool _refreshing = false;

Future<void> refreshDevices() async {
  if (_refreshing) return;
  _refreshing = true;
  try {
    // ... existing logic ...
  } finally {
    _refreshing = false;
  }
}
```
- **WHY:** Prevents doubled ADB server load and eliminates the race condition where an older, slower refresh overwrites a newer result.

---

## PERF-18: autoSetupService.runAutoSetup blocks background init with artificial delays

- **FILE:LINE** `openmob_hub/lib/services/auto_setup_service.dart:60-61, 74, 108, 127`
- **IMPACT:** LOW
- **CURRENT:** `runAutoSetup()` includes four `Future.delayed(Duration(milliseconds: 300-500))` calls that serve no purpose other than making the progress bar visible. Total artificial delay: ~1.4 seconds. Since this runs before the initial `deviceManager.refreshDevices()`, the device list stays empty for an extra 1.4 seconds on every startup.
- **FIX:** Remove all artificial delays:
```dart
// Delete these lines:
await Future.delayed(const Duration(milliseconds: 300)); // line 61
await Future.delayed(const Duration(milliseconds: 300)); // line 74
await Future.delayed(const Duration(milliseconds: 500)); // line 108
await Future.delayed(const Duration(milliseconds: 300)); // line 127
```
- **WHY:** Users see their devices 1.4 seconds sooner on every launch. The progress UI already updates based on phase transitions, so the delays are cosmetic waste.

---

## PERF-19: grantAllPermissions runs ADB commands sequentially for every permission

- **FILE:LINE** `openmob_hub/lib/services/action_service.dart:714-729`
- **IMPACT:** MEDIUM
- **CURRENT:** `grantAllPermissions()` first dumps the full package info (which can be huge -- tens of KB), then iterates over every matched permission and calls `adb shell pm grant` one-by-one in a `for` loop. A typical app has 10-30 permissions, resulting in 10-30 sequential ADB calls taking 3-10 seconds.
- **FIX:** Batch the grant commands or run them in parallel groups:
```dart
// Run grants in parallel batches of 5
final permissions = // ... existing extraction ...
for (var i = 0; i < permissions.length; i += 5) {
  final batch = permissions.skip(i).take(5).map((perm) async {
    try {
      final r = await _adb.run(serial, ['shell', 'pm', 'grant', packageName, perm]);
      return r.exitCode == 0 ? 1 : 0;
    } catch (_) {
      return 0;
    }
  });
  final results = await Future.wait(batch);
  granted += results.fold(0, (a, b) => a + b);
}
```
- **WHY:** With parallelism of 5, a 20-permission grant drops from ~7s to ~1.5s. The AI agent calling this tool gets a response 4x faster.

---

## PERF-20: Rust busy_detector tick rate of 100ms creates unnecessary wake-ups

- **FILE:LINE** `openmob_bridge/src/busy_detector.rs:20`
- **IMPACT:** LOW
- **CURRENT:** The detector ticks every 100ms to check if the idle timeout (500ms) has been reached. Since the idle_timeout is 500ms, a tick rate of 100ms means 5 wake-ups before the earliest possible idle detection, adding up to 100ms of latency to idle detection (worst case: output stops at tick N, idle detected at tick N+5, but the check fires at arbitrary phase offsets). Meanwhile, the 100ms tick generates 600 wake-ups per minute that all acquire the tokio mutex.
- **FIX:** Increase tick rate to 200ms (still well under the 500ms idle threshold):
```rust
tick_rate: Duration::from_millis(200),
```
Or better, use `tokio::time::sleep_until(last_output + idle_timeout)` instead of polling, which eliminates periodic wake-ups entirely.
- **WHY:** Halves the number of mutex acquisitions per minute (600 -> 300). With the sleep_until approach, wake-ups drop to exactly 1 per idle transition.

---

## PERF-21: _parsePngDimensions copies the entire byte array

- **FILE:LINE** `openmob_hub/lib/services/screenshot_service.dart:80-81`
- **IMPACT:** LOW
- **CURRENT:** `_parsePngDimensions` calls `Uint8List.fromList(bytes)` to create a copy of the entire PNG byte array (3-6MB) just to read 8 bytes (width + height at offsets 16-23). This allocates a completely unnecessary duplicate of the screenshot data.
- **FIX:** If `bytes` is already a `Uint8List`, cast directly. If it is `List<int>`, only copy the header:
```dart
({int width, int height}) _parsePngDimensions(List<int> bytes) {
  if (bytes.length < 24) return (width: 0, height: 0);
  if (bytes[0] != 0x89 || bytes[1] != 0x50 || bytes[2] != 0x4E || bytes[3] != 0x47) {
    return (width: 0, height: 0);
  }
  try {
    // Only need first 24 bytes for IHDR dimensions
    final header = bytes is Uint8List ? bytes : Uint8List.fromList(bytes.take(24).toList());
    final byteData = ByteData.sublistView(header, 0, 24);
    final width = byteData.getUint32(16, Endian.big);
    final height = byteData.getUint32(20, Endian.big);
    return (width: width, height: height);
  } catch (_) {
    return (width: 0, height: 0);
  }
}
```
- **WHY:** Saves 3-6MB of allocation per screenshot capture. With captures every 500ms in live preview, this saves ~600MB-1.2GB of allocations per minute in the GC.

---

## PERF-22: base64Encode in captureScreenshot creates a massive intermediate string

- **FILE:LINE** `openmob_hub/lib/services/screenshot_service.dart:39`
- **IMPACT:** LOW (for API use), HIGH (if called from live preview path)
- **CURRENT:** `base64Encode(bytes)` on a 5MB PNG produces a ~6.7MB string. The function signature returns this as a record, so the caller retains both the raw bytes and the base64 string. The capturePreview path does NOT base64-encode (correct), but the API screenshot endpoint does.
- **FIX:** Do not pre-compute base64 in the service. Let the API route encode lazily:
```dart
// Service returns raw bytes + dimensions
Future<({Uint8List bytes, int width, int height})> captureScreenshot(String serial) async {
  // ... capture bytes ...
  return (bytes: bytes, width: dims.width, height: dims.height);
}

// Route encodes to base64 only when building JSON response
final result = await ss.captureScreenshot(device.serial);
return Response.ok(jsonEncode({
  'screenshot': base64Encode(result.bytes),
  'width': result.width,
  'height': result.height,
}));
```
- **WHY:** Keeps the service layer allocation-efficient. Callers that need raw bytes (like the test runner's screenshot comparison) avoid the base64 overhead entirely.

---

## PERF-23: BehaviorSubject in DeviceManager emits new list on every bridge start/stop

- **FILE:LINE** `openmob_hub/lib/services/device_manager.dart:191-208`
- **CURRENT:** `startBridge` and `stopBridge` iterate the entire device list with `.map()` to update one device, creating a new list each time. This triggers all `ValueStreamBuilder` subscribers to rebuild even though only one device changed.
- **IMPACT:** LOW
- **FIX:** This is acceptable for the current scale (few devices). If device count grows, consider a per-device stream or `distinct()` on the stream.
- **WHY:** Not a real bottleneck now, but worth noting for future scaling.

---

## PERF-24: main.dart blocks on autoSetupService BEFORE initial device scan

- **FILE:LINE** `openmob_hub/lib/main.dart:142-155`
- **IMPACT:** MEDIUM
- **CURRENT:** `_initBackground()` awaits `autoSetupService.runAutoSetup()` before calling `deviceManager.refreshDevices()`. Auto-setup checks tools, potentially downloads binaries, builds MCP, configures AI tools -- this can take 2-30 seconds. The device list remains empty the entire time. Users see "No devices connected" even when devices are plugged in.
- **FIX:** Run auto-setup and initial device scan in parallel:
```dart
Future<void> _initBackground() async {
  // Run in parallel -- device scan should not wait for auto-setup
  await Future.wait([
    _runAutoSetup(),
    _runInitialScan(),
  ]);

  // Start device polling
  Stream.periodic(const Duration(seconds: 5)).listen((_) {
    try { deviceManager.refreshDevices(); } catch (_) {}
  });

  // Check for updates last
  try { await updateService.checkForUpdate(); } catch (_) {}
}

Future<void> _runAutoSetup() async {
  try { await autoSetupService.runAutoSetup(); }
  catch (e) { logService.addLine('hub', 'Auto-setup failed: $e', level: LogLevel.warning); }
}

Future<void> _runInitialScan() async {
  try { await deviceManager.refreshDevices(); }
  catch (e) { logService.addLine('hub', 'Initial device scan failed: $e', level: LogLevel.warning); }
}
```
- **WHY:** Devices appear in the UI within 1 second of launch instead of after 2-30 seconds of auto-setup. This is the single highest-impact UX improvement for first launch.

---

## PERF-25: stopBridge uses Process.runSync for pkill/taskkill

- **FILE:LINE** `openmob_hub/lib/services/process_manager.dart:452-459`
- **IMPACT:** LOW
- **CURRENT:** `stopBridge()` calls `Process.runSync('pkill', ...)` after killing the managed process. This synchronous call can take 50-200ms and runs on the main isolate.
- **FIX:** Use async `Process.run`:
```dart
try {
  if (Platform.isWindows) {
    await Process.run('taskkill', ['/F', '/IM', 'aibridge.exe']);
  } else {
    await Process.run('pkill', ['-f', 'aibridge.*--port']);
  }
} catch (_) {}
```
- **WHY:** The stop button in the UI should not freeze the app for 200ms.

---

## Summary by Impact

### HIGH (user-visible jank, sluggish startup, excessive resource use)
| # | Issue | Estimated Savings |
|---|-------|-------------------|
| PERF-01 | Process.runSync in AdbService.adbPath | 50-200ms startup |
| PERF-02 | Sequential device enrichment | 2-4s per refresh with multiple devices |
| PERF-03 | Full enrichment every 5s | ~40 unnecessary processes/min |
| PERF-04 | Full-res screenshots in live preview | 20-30x memory reduction per frame |
| PERF-24 | Auto-setup blocks device scan | 2-30s faster device appearance |

### MEDIUM (noticeable under load or specific conditions)
| # | Issue | Estimated Savings |
|---|-------|-------------------|
| PERF-05 | Timer.periodic vs delay-after-complete | Smoother frame pacing |
| PERF-06 | Process.runSync in _detectAgents | 150-300ms startup |
| PERF-07 | Process.runSync in _terminalEmulator/_bridgeBinary | Up to 800ms startup |
| PERF-08 | Process.runSync in _checkAiBridge | 50-100ms startup |
| PERF-09 | Process.runSync in _checkAdb | 50-100ms startup |
| PERF-10 | Sequential tool checks | 400ms-2s startup |
| PERF-11 | LogService list copy per addLine | Reduced GC pressure |
| PERF-12 | Base64 screenshot in API | 20-30x smaller API responses |
| PERF-14 | block_on inside spawn_blocking | Better injection responsiveness |
| PERF-16 | No timeout on simctl | Prevents indefinite hangs |
| PERF-17 | No concurrent refresh guard | Prevents doubled ADB load |
| PERF-19 | Sequential permission grants | 3-10s -> 1-2s |

### LOW (correct but not user-visible)
| # | Issue | Estimated Savings |
|---|-------|-------------------|
| PERF-13 | adbPath event loop overhead | Microseconds per call |
| PERF-15 | Vec::remove(0) in queue | O(n) -> O(1) dequeue |
| PERF-18 | Artificial delays in auto-setup | 1.4s startup |
| PERF-20 | 100ms tick rate in busy_detector | 300 fewer wakeups/min |
| PERF-21 | Full PNG copy for dimension parsing | 3-6MB saved per capture |
| PERF-22 | Eager base64 encoding | 6.7MB saved when raw bytes suffice |
| PERF-23 | Full list rebuild on bridge toggle | Negligible at current scale |
| PERF-25 | Process.runSync in stopBridge | 50-200ms UI freeze |

---

## Recommended Fix Order

1. **PERF-24** -- Run auto-setup and device scan in parallel (biggest UX win, 5 min fix)
2. **PERF-03** -- Cache device enrichment, only enrich new serials (biggest resource win)
3. **PERF-04** -- Downscale preview screenshots (biggest memory win)
4. **PERF-02** -- Parallelize multi-device enrichment
5. **PERF-01, 06, 07, 08, 09** -- Replace all Process.runSync with Process.run (batch fix)
6. **PERF-10** -- Parallelize checkAll
7. **PERF-05** -- Fix live preview timer
8. **PERF-17** -- Add refresh guard
9. **PERF-11** -- Fix log service allocation pattern
10. Everything else
