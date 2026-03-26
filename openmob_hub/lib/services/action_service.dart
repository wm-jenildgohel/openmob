import '../core/constants.dart';
import '../models/action_result.dart';
import 'adb_service.dart';
import 'device_manager.dart';
import 'idb_service.dart';
import 'simctl_service.dart';
import 'ui_tree_service.dart';

class ActionService {
  final AdbService _adb;
  final UiTreeService _uiTree;
  final SimctlService? _simctl;
  final IdbService? _idb;
  final DeviceManager _dm;

  ActionService(
    this._adb,
    this._uiTree, {
    SimctlService? simctl,
    IdbService? idb,
    required DeviceManager dm,
  })  : _simctl = simctl,
        _idb = idb,
        _dm = dm;

  /// Check if a device is an iOS platform device.
  bool _isIos(String serial) {
    final d = _dm.getDevice(serial);
    return d?.platform == 'ios';
  }

  /// Tap at absolute screen coordinates.
  Future<ActionResult> tap(String serial, int x, int y) async {
    if (_isIos(serial)) {
      if (_idb != null) {
        try {
          await _idb.tap(serial, x, y);
          return ActionResult.ok();
        } catch (e) {
          return ActionResult.fail('iOS tap failed: $e');
        }
      }
      return ActionResult.fail('idb not installed -- tap requires idb on iOS simulators');
    }

    try {
      await _adb.run(serial, ['shell', 'input', 'tap', '$x', '$y']);
      return ActionResult.ok();
    } catch (e) {
      return ActionResult.fail('Tap failed: $e');
    }
  }

  /// Tap an element by its UI tree index (resolves to center of bounds).
  Future<ActionResult> tapElement(String serial, int index) async {
    try {
      final nodes = await _uiTree.getUiTree(serial);
      final matches = nodes.where((n) => n.index == index);
      if (matches.isEmpty) {
        return ActionResult.fail('Element with index $index not found');
      }
      final node = matches.first;
      final centerX = node.bounds.centerX;
      final centerY = node.bounds.centerY;
      return tap(serial, centerX, centerY);
    } catch (e) {
      return ActionResult.fail('Tap element failed: $e');
    }
  }

  /// Type text on the device.
  Future<ActionResult> typeText(String serial, String text) async {
    if (_isIos(serial)) {
      if (_idb != null) {
        try {
          await _idb.typeText(serial, text);
          return ActionResult.ok();
        } catch (e) {
          return ActionResult.fail('iOS type text failed: $e');
        }
      }
      return ActionResult.fail('idb not installed -- type text requires idb on iOS simulators');
    }

    try {
      // Escape special characters for ADB shell input text
      var escaped = text
          .replaceAll(r'\', r'\\')
          .replaceAll(' ', '%s')
          .replaceAll('&', r'\&')
          .replaceAll('<', r'\<')
          .replaceAll('>', r'\>')
          .replaceAll("'", r"\'")
          .replaceAll('"', r'\"')
          .replaceAll('(', r'\(')
          .replaceAll(')', r'\)')
          .replaceAll(';', r'\;')
          .replaceAll('|', r'\|')
          .replaceAll('`', r'\`');

      await _adb.run(serial, ['shell', 'input', 'text', escaped]);
      return ActionResult.ok();
    } catch (e) {
      return ActionResult.fail('Type text failed: $e');
    }
  }

  /// Swipe from (x1,y1) to (x2,y2) over the given duration.
  Future<ActionResult> swipe(
    String serial,
    int x1,
    int y1,
    int x2,
    int y2, {
    int durationMs = 300,
  }) async {
    if (_isIos(serial)) {
      if (_idb != null) {
        try {
          await _idb.swipe(serial, x1, y1, x2, y2, durationMs: durationMs);
          return ActionResult.ok();
        } catch (e) {
          return ActionResult.fail('iOS swipe failed: $e');
        }
      }
      return ActionResult.fail('idb not installed -- swipe requires idb on iOS simulators');
    }

    try {
      await _adb.run(serial, [
        'shell', 'input', 'swipe',
        '$x1', '$y1', '$x2', '$y2', '$durationMs',
      ]);
      return ActionResult.ok();
    } catch (e) {
      return ActionResult.fail('Swipe failed: $e');
    }
  }

  /// Send a key event (hardware key press).
  Future<ActionResult> pressKey(String serial, int keyCode) async {
    if (_isIos(serial)) {
      if (_idb != null) {
        try {
          // Map common ADB keyCodes to idb button names
          String? button;
          if (keyCode == AdbKeyCodes.home) {
            button = 'HOME';
          } else if (keyCode == AdbKeyCodes.power) {
            button = 'LOCK';
          }

          if (button != null) {
            await _idb.pressButton(serial, button);
            return ActionResult.ok();
          }
          return ActionResult.fail('Key code $keyCode not supported on iOS');
        } catch (e) {
          return ActionResult.fail('iOS press key failed: $e');
        }
      }
      return ActionResult.fail('idb not installed -- press key requires idb on iOS simulators');
    }

    try {
      await _adb.run(serial, ['shell', 'input', 'keyevent', '$keyCode']);
      return ActionResult.ok();
    } catch (e) {
      return ActionResult.fail('Press key failed: $e');
    }
  }

  /// Wake screen + swipe up to unlock (no PIN/pattern).
  Future<ActionResult> unlockDevice(String serial) async {
    if (_isIos(serial)) {
      // iOS simulators are always unlocked
      return ActionResult.ok(data: {'message': 'iOS simulators do not have lock screens'});
    }

    try {
      // Send WAKEUP keyevent (224) — only wakes, never turns off
      await _adb.run(serial, ['shell', 'input', 'keyevent', '224']);
      await Future.delayed(const Duration(milliseconds: 500));

      // Get screen dimensions for swipe
      final device = _dm.getDevice(serial);
      final w = device?.screenWidth ?? 1080;
      final h = device?.screenHeight ?? 1920;
      final cx = w ~/ 2;

      // Swipe up from bottom to dismiss lock screen
      await _adb.run(serial, [
        'shell', 'input', 'swipe',
        '$cx', '${(h * 0.85).toInt()}',
        '$cx', '${(h * 0.3).toInt()}',
        '300',
      ]);
      await Future.delayed(const Duration(milliseconds: 500));

      // Dismiss any remaining keyguard
      await _adb.run(serial, ['shell', 'input', 'keyevent', '82']); // MENU dismisses keyguard

      return ActionResult.ok(data: {'message': 'Device unlocked'});
    } catch (e) {
      return ActionResult.fail('Unlock failed: $e');
    }
  }

  /// Press the Home button.
  Future<ActionResult> goHome(String serial) async {
    if (_isIos(serial)) {
      if (_idb != null) {
        try {
          await _idb.pressButton(serial, 'HOME');
          return ActionResult.ok();
        } catch (e) {
          return ActionResult.fail('iOS go home failed: $e');
        }
      }
      return ActionResult.fail('idb not installed -- go home requires idb on iOS simulators');
    }

    return pressKey(serial, AdbKeyCodes.home);
  }

  /// Launch an app by package/bundle name.
  Future<ActionResult> launchApp(String serial, String packageName) async {
    if (_isIos(serial)) {
      if (_simctl != null) {
        try {
          await _simctl.launchApp(serial, packageName);
          return ActionResult.ok();
        } catch (e) {
          return ActionResult.fail('iOS launch app failed: $e');
        }
      }
      return ActionResult.fail('simctl not available -- cannot launch apps on iOS');
    }

    try {
      await _adb.run(serial, [
        'shell', 'monkey', '-p', packageName,
        '-c', 'android.intent.category.LAUNCHER', '1',
      ]);
      return ActionResult.ok();
    } catch (e) {
      return ActionResult.fail('Launch app failed: $e');
    }
  }

  /// Force-stop / terminate an app by package/bundle name.
  Future<ActionResult> terminateApp(String serial, String packageName) async {
    if (_isIos(serial)) {
      if (_simctl != null) {
        try {
          await _simctl.terminateApp(serial, packageName);
          return ActionResult.ok();
        } catch (e) {
          return ActionResult.fail('iOS terminate app failed: $e');
        }
      }
      return ActionResult.fail('simctl not available -- cannot terminate apps on iOS');
    }

    try {
      await _adb.run(serial, ['shell', 'am', 'force-stop', packageName]);
      return ActionResult.ok();
    } catch (e) {
      return ActionResult.fail('Terminate app failed: $e');
    }
  }

  /// Open a URL in the default browser/handler.
  Future<ActionResult> openUrl(String serial, String url) async {
    if (_isIos(serial)) {
      if (_simctl != null) {
        try {
          await _simctl.openUrl(serial, url);
          return ActionResult.ok();
        } catch (e) {
          return ActionResult.fail('iOS open URL failed: $e');
        }
      }
      return ActionResult.fail('simctl not available -- cannot open URLs on iOS');
    }

    try {
      await _adb.run(serial, [
        'shell', 'am', 'start',
        '-a', 'android.intent.action.VIEW',
        '-d', url,
      ]);
      return ActionResult.ok();
    } catch (e) {
      return ActionResult.fail('Open URL failed: $e');
    }
  }

  /// Long press at coordinates (simulated via swipe with same start/end).
  Future<ActionResult> longPress(
    String serial,
    int x,
    int y, {
    int durationMs = 1500,
  }) async {
    if (_isIos(serial)) {
      // Long press on iOS: tap and hold is not directly supported by idb
      // but can be approximated with a zero-distance swipe
      if (_idb != null) {
        try {
          await _idb.swipe(serial, x, y, x, y, durationMs: durationMs);
          return ActionResult.ok();
        } catch (e) {
          return ActionResult.fail('iOS long press failed: $e');
        }
      }
      return ActionResult.fail('idb not installed -- long press requires idb on iOS simulators');
    }

    try {
      await _adb.run(serial, [
        'shell', 'input', 'swipe',
        '$x', '$y', '$x', '$y', '$durationMs',
      ]);
      return ActionResult.ok();
    } catch (e) {
      return ActionResult.fail('Long press failed: $e');
    }
  }

  /// Pinch gesture (approximate -- ADB lacks native multi-touch).
  /// For zoom in: two swipes from outer points toward center.
  /// For zoom out: two swipes from center toward outer points.
  Future<ActionResult> pinch(
    String serial,
    int centerX,
    int centerY, {
    bool zoomIn = true,
    int distance = 200,
    int durationMs = 500,
  }) async {
    if (_isIos(serial)) {
      return ActionResult.fail('Pinch gesture not supported on iOS simulators');
    }

    try {
      final half = distance ~/ 2;
      if (zoomIn) {
        // Swipe from outer points toward center
        await Future.wait([
          _adb.run(serial, [
            'shell', 'input', 'swipe',
            '${centerX - half}', '$centerY',
            '$centerX', '$centerY', '$durationMs',
          ]),
          _adb.run(serial, [
            'shell', 'input', 'swipe',
            '${centerX + half}', '$centerY',
            '$centerX', '$centerY', '$durationMs',
          ]),
        ]);
      } else {
        // Swipe from center toward outer points
        await Future.wait([
          _adb.run(serial, [
            'shell', 'input', 'swipe',
            '$centerX', '$centerY',
            '${centerX - half}', '$centerY', '$durationMs',
          ]),
          _adb.run(serial, [
            'shell', 'input', 'swipe',
            '$centerX', '$centerY',
            '${centerX + half}', '$centerY', '$durationMs',
          ]),
        ]);
      }
      return ActionResult.ok(data: {
        'note': 'Pinch gesture is approximate -- ADB does not natively support multi-touch',
      });
    } catch (e) {
      return ActionResult.fail('Pinch failed: $e');
    }
  }

  /// Execute a named gesture with parameters.
  Future<ActionResult> gesture(
    String serial,
    String type,
    Map<String, dynamic> params,
  ) async {
    switch (type) {
      case 'long_press':
        return longPress(
          serial,
          (params['x'] as num).toInt(),
          (params['y'] as num).toInt(),
          durationMs: (params['duration'] as num?)?.toInt() ?? 1500,
        );
      case 'pinch_in':
        return pinch(
          serial,
          (params['x'] as num).toInt(),
          (params['y'] as num).toInt(),
          zoomIn: true,
          distance: (params['distance'] as num?)?.toInt() ?? 200,
          durationMs: (params['duration'] as num?)?.toInt() ?? 500,
        );
      case 'pinch_out':
        return pinch(
          serial,
          (params['x'] as num).toInt(),
          (params['y'] as num).toInt(),
          zoomIn: false,
          distance: (params['distance'] as num?)?.toInt() ?? 200,
          durationMs: (params['duration'] as num?)?.toInt() ?? 500,
        );
      case 'double_tap':
        final x = (params['x'] as num).toInt();
        final y = (params['y'] as num).toInt();
        final first = await tap(serial, x, y);
        if (!first.success) return first;
        await Future.delayed(const Duration(milliseconds: 100));
        return tap(serial, x, y);
      case 'drag':
        return drag(
          serial,
          (params['x1'] as num).toInt(),
          (params['y1'] as num).toInt(),
          (params['x2'] as num).toInt(),
          (params['y2'] as num).toInt(),
          durationMs: (params['duration'] as num?)?.toInt() ?? 1000,
        );
      default:
        return ActionResult.fail('Unknown gesture type: $type');
    }
  }

  // ─── P0: App Install / Uninstall ───

  /// Install an APK on the device from a local file path.
  Future<ActionResult> installApp(String serial, String apkPath, {bool replace = true, bool grantPermissions = true}) async {
    if (_isIos(serial)) {
      return ActionResult.fail('APK install not supported on iOS — use .ipa with Xcode');
    }
    try {
      final args = ['install'];
      if (replace) args.add('-r');
      if (grantPermissions) args.add('-g');
      args.add(apkPath);
      final result = await _adb.runGlobal(['-s', serial, ...args]);
      if (result.exitCode != 0 || (result.stdout as String).contains('Failure')) {
        return ActionResult.fail('Install failed: ${result.stdout}');
      }
      return ActionResult.ok(data: {'message': 'App installed successfully'});
    } catch (e) {
      return ActionResult.fail('Install failed: $e');
    }
  }

  /// Uninstall an app by package name.
  Future<ActionResult> uninstallApp(String serial, String packageName) async {
    if (_isIos(serial)) {
      if (_simctl != null) {
        try {
          await _simctl.uninstallApp(serial, packageName);
          return ActionResult.ok();
        } catch (e) {
          return ActionResult.fail('iOS uninstall failed: $e');
        }
      }
      return ActionResult.fail('simctl not available');
    }
    try {
      final result = await _adb.run(serial, ['shell', 'pm', 'uninstall', packageName]);
      if ((result.stdout as String).contains('Success')) {
        return ActionResult.ok(data: {'message': '$packageName uninstalled'});
      }
      return ActionResult.fail('Uninstall failed: ${result.stdout}');
    } catch (e) {
      return ActionResult.fail('Uninstall failed: $e');
    }
  }

  // ─── P0: List Installed Apps ───

  /// List installed apps (optionally filter to 3rd-party only).
  Future<ActionResult> listApps(String serial, {bool thirdPartyOnly = true}) async {
    if (_isIos(serial)) {
      return ActionResult.fail('List apps not supported on iOS simulators via this API');
    }
    try {
      final flag = thirdPartyOnly ? '-3' : '';
      final result = await _adb.run(serial, ['shell', 'pm', 'list', 'packages', if (flag.isNotEmpty) flag]);
      final packages = (result.stdout as String)
          .replaceAll('\r', '')
          .split('\n')
          .where((l) => l.startsWith('package:'))
          .map((l) => l.replaceFirst('package:', '').trim())
          .where((p) => p.isNotEmpty)
          .toList();
      return ActionResult.ok(data: {'packages': packages, 'count': packages.length});
    } catch (e) {
      return ActionResult.fail('List apps failed: $e');
    }
  }

  // ─── P0: Get Current Activity ───

  /// Get the currently focused activity (foreground app + screen).
  Future<ActionResult> getCurrentActivity(String serial) async {
    if (_isIos(serial)) {
      return ActionResult.fail('Get current activity not supported on iOS');
    }
    try {
      final result = await _adb.run(serial, ['shell', 'dumpsys', 'activity', 'activities']);
      final stdout = (result.stdout as String).replaceAll('\r', '');
      // Parse "mResumedActivity" or "mFocusedActivity" line
      final lines = stdout.split('\n');
      for (final line in lines) {
        if (line.contains('mResumedActivity') || line.contains('mFocusedActivity')) {
          final match = RegExp(r'(\S+/\S+)').firstMatch(line);
          if (match != null) {
            final activity = match.group(1)!;
            final parts = activity.split('/');
            return ActionResult.ok(data: {
              'package': parts[0],
              'activity': parts.length > 1 ? parts[1] : '',
              'full': activity,
            });
          }
        }
      }
      return ActionResult.ok(data: {'package': 'unknown', 'activity': 'unknown'});
    } catch (e) {
      return ActionResult.fail('Get current activity failed: $e');
    }
  }

  // ─── P0: Clear App Data ───

  /// Clear all data for an app (like a fresh install).
  Future<ActionResult> clearAppData(String serial, String packageName) async {
    if (_isIos(serial)) {
      return ActionResult.fail('Clear app data not supported on iOS simulators');
    }
    try {
      final result = await _adb.run(serial, ['shell', 'pm', 'clear', packageName]);
      if ((result.stdout as String).contains('Success')) {
        return ActionResult.ok(data: {'message': '$packageName data cleared'});
      }
      return ActionResult.fail('Clear data failed: ${result.stdout}');
    } catch (e) {
      return ActionResult.fail('Clear data failed: $e');
    }
  }

  // ─── P0: Logcat (Device Logs) ───

  /// Get recent device logs filtered by tag, level, and line count.
  Future<ActionResult> getLogcat(String serial, {int lines = 100, String? tag, String? level}) async {
    if (_isIos(serial)) {
      return ActionResult.fail('Logcat not available on iOS — use Console.app');
    }
    try {
      final args = <String>['shell', 'logcat', '-d', '-t', '$lines'];
      if (tag != null && level != null) {
        args.addAll(['-s', '$tag:${level.toUpperCase().substring(0, 1)}']);
      } else if (tag != null) {
        args.addAll(['-s', '$tag:V']);
      } else if (level != null) {
        args.addAll(['*:${level.toUpperCase().substring(0, 1)}']);
      }
      final result = await _adb.run(serial, args, timeout: const Duration(seconds: 15));
      final logLines = (result.stdout as String)
          .replaceAll('\r', '')
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      return ActionResult.ok(data: {'logs': logLines, 'count': logLines.length});
    } catch (e) {
      return ActionResult.fail('Logcat failed: $e');
    }
  }

  /// Clear the logcat buffer.
  Future<ActionResult> clearLogcat(String serial) async {
    try {
      await _adb.run(serial, ['shell', 'logcat', '-c']);
      return ActionResult.ok(data: {'message': 'Logcat buffer cleared'});
    } catch (e) {
      return ActionResult.fail('Clear logcat failed: $e');
    }
  }

  // ─── P0: Wait for Element ───

  /// Wait until a UI element matching the filter appears on screen.
  Future<ActionResult> waitForElement(String serial, {String? text, String? resourceId, int timeoutMs = 10000, int pollMs = 500}) async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsedMilliseconds < timeoutMs) {
      try {
        final nodes = await _uiTree.getUiTree(serial);
        final match = nodes.where((n) {
          if (text != null && n.text.contains(text)) return true;
          if (resourceId != null && n.resourceId.contains(resourceId)) return true;
          return false;
        });
        if (match.isNotEmpty) {
          final found = match.first;
          return ActionResult.ok(data: {
            'found': true,
            'index': found.index,
            'text': found.text,
            'resourceId': found.resourceId,
            'bounds': {
              'centerX': found.bounds.centerX,
              'centerY': found.bounds.centerY,
            },
            'waitedMs': stopwatch.elapsedMilliseconds,
          });
        }
      } catch (_) {
        // UI tree fetch may fail during transitions — keep polling
      }
      await Future.delayed(Duration(milliseconds: pollMs));
    }
    return ActionResult.fail('Element not found after ${timeoutMs}ms${text != null ? ' (text: "$text")' : ''}${resourceId != null ? ' (resourceId: "$resourceId")' : ''}');
  }

  // ─── P1: File Push / Pull ───

  /// Push a file from host to device.
  Future<ActionResult> pushFile(String serial, String localPath, String remotePath) async {
    try {
      final result = await _adb.runGlobal(['-s', serial, 'push', localPath, remotePath]);
      if (result.exitCode != 0) {
        return ActionResult.fail('Push failed: ${result.stderr}');
      }
      return ActionResult.ok(data: {'message': 'Pushed $localPath to $remotePath'});
    } catch (e) {
      return ActionResult.fail('Push failed: $e');
    }
  }

  /// Pull a file from device to host.
  Future<ActionResult> pullFile(String serial, String remotePath, String localPath) async {
    try {
      final result = await _adb.runGlobal(['-s', serial, 'pull', remotePath, localPath]);
      if (result.exitCode != 0) {
        return ActionResult.fail('Pull failed: ${result.stderr}');
      }
      return ActionResult.ok(data: {'message': 'Pulled $remotePath to $localPath'});
    } catch (e) {
      return ActionResult.fail('Pull failed: $e');
    }
  }

  /// List files on device at the given path.
  Future<ActionResult> listFiles(String serial, String path) async {
    try {
      final result = await _adb.run(serial, ['shell', 'ls', '-la', path]);
      final files = (result.stdout as String)
          .replaceAll('\r', '')
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      return ActionResult.ok(data: {'path': path, 'files': files, 'count': files.length});
    } catch (e) {
      return ActionResult.fail('List files failed: $e');
    }
  }

  // ─── P1: Connectivity Toggles ───

  /// Toggle WiFi on/off.
  Future<ActionResult> setWifi(String serial, bool enabled) async {
    try {
      await _adb.run(serial, ['shell', 'svc', 'wifi', enabled ? 'enable' : 'disable']);
      return ActionResult.ok(data: {'wifi': enabled ? 'enabled' : 'disabled'});
    } catch (e) {
      return ActionResult.fail('WiFi toggle failed: $e');
    }
  }

  /// Toggle airplane mode on/off.
  Future<ActionResult> setAirplaneMode(String serial, bool enabled) async {
    try {
      await _adb.run(serial, ['shell', 'cmd', 'connectivity', 'airplane-mode', enabled ? 'enable' : 'disable']);
      return ActionResult.ok(data: {'airplaneMode': enabled ? 'enabled' : 'disabled'});
    } catch (e) {
      return ActionResult.fail('Airplane mode toggle failed: $e');
    }
  }

  // ─── P1: Screen Rotation ───

  /// Set screen rotation. 0=natural, 1=90°, 2=180°, 3=270°.
  Future<ActionResult> setRotation(String serial, int rotation) async {
    try {
      // Disable auto-rotation first
      await _adb.run(serial, ['shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0']);
      // Set rotation
      await _adb.run(serial, ['shell', 'settings', 'put', 'system', 'user_rotation', '$rotation']);
      final names = {0: 'portrait', 1: 'landscape', 2: 'reverse portrait', 3: 'reverse landscape'};
      return ActionResult.ok(data: {'rotation': rotation, 'orientation': names[rotation] ?? 'unknown'});
    } catch (e) {
      return ActionResult.fail('Set rotation failed: $e');
    }
  }

  // ─── P1: Grant Permissions ───

  /// Grant all runtime permissions to an app.
  Future<ActionResult> grantAllPermissions(String serial, String packageName) async {
    try {
      final result = await _adb.run(serial, ['shell', 'dumpsys', 'package', packageName]);
      final stdout = (result.stdout as String).replaceAll('\r', '');
      final permissions = RegExp(r'android\.permission\.\w+')
          .allMatches(stdout)
          .map((m) => m.group(0)!)
          .toSet()
          .toList();
      int granted = 0;
      for (final perm in permissions) {
        try {
          final r = await _adb.run(serial, ['shell', 'pm', 'grant', packageName, perm]);
          if (r.exitCode == 0) granted++;
        } catch (_) {}
      }
      return ActionResult.ok(data: {
        'message': 'Granted $granted/${permissions.length} permissions',
        'granted': granted,
        'total': permissions.length,
      });
    } catch (e) {
      return ActionResult.fail('Grant permissions failed: $e');
    }
  }

  // ─── P1: Drag and Drop ───

  /// Drag from (x1,y1) to (x2,y2) with a long press at start.
  Future<ActionResult> drag(String serial, int x1, int y1, int x2, int y2, {int durationMs = 1000}) async {
    try {
      // Drag = slow swipe (longer duration simulates drag)
      await _adb.run(serial, [
        'shell', 'input', 'swipe', '$x1', '$y1', '$x2', '$y2', '$durationMs',
      ]);
      return ActionResult.ok(data: {'message': 'Dragged from ($x1,$y1) to ($x2,$y2)'});
    } catch (e) {
      return ActionResult.fail('Drag failed: $e');
    }
  }

  // ─── P2: Keyboard Detection ───

  /// Check if the soft keyboard is currently showing.
  Future<ActionResult> isKeyboardShowing(String serial) async {
    try {
      final result = await _adb.run(serial, ['shell', 'dumpsys', 'input_method']);
      final stdout = (result.stdout as String).replaceAll('\r', '');
      final showing = stdout.contains('mInputShown=true');
      return ActionResult.ok(data: {'keyboardShowing': showing});
    } catch (e) {
      return ActionResult.fail('Keyboard check failed: $e');
    }
  }

  // ─── P2: Screen Recording ───

  /// Start screen recording on the device.
  Future<ActionResult> startScreenRecording(String serial, {int maxDurationSec = 180}) async {
    try {
      // screenrecord runs in background, stops after duration or when killed
      _adb.run(serial, [
        'shell', 'screenrecord', '--time-limit', '$maxDurationSec', '/sdcard/openmob_recording.mp4',
      ]); // Don't await — runs in background
      return ActionResult.ok(data: {'message': 'Recording started (max ${maxDurationSec}s)', 'path': '/sdcard/openmob_recording.mp4'});
    } catch (e) {
      return ActionResult.fail('Screen recording failed: $e');
    }
  }

  /// Stop screen recording and return the file path.
  Future<ActionResult> stopScreenRecording(String serial) async {
    try {
      // Kill screenrecord process
      await _adb.run(serial, ['shell', 'pkill', '-f', 'screenrecord']);
      await Future.delayed(const Duration(seconds: 1));
      return ActionResult.ok(data: {'message': 'Recording stopped', 'path': '/sdcard/openmob_recording.mp4'});
    } catch (e) {
      return ActionResult.fail('Stop recording failed: $e');
    }
  }

  // ─── P2: Notifications ───

  /// Get current notification bar content.
  Future<ActionResult> getNotifications(String serial) async {
    try {
      final result = await _adb.run(serial, ['shell', 'dumpsys', 'notification', '--noredact']);
      final stdout = (result.stdout as String).replaceAll('\r', '');
      // Parse notification entries
      final notifications = <Map<String, String>>[];
      final titlePattern = RegExp(r'android\.title=String \((.+?)\)');
      final textPattern = RegExp(r'android\.text=String \((.+?)\)');

      final records = stdout.split('NotificationRecord{');
      for (final record in records.skip(1)) {
        final pkg = RegExp(r'pkg=(\S+)').firstMatch(record)?.group(1) ?? '';
        final title = titlePattern.firstMatch(record)?.group(1) ?? '';
        final text = textPattern.firstMatch(record)?.group(1) ?? '';
        if (pkg.isNotEmpty) {
          notifications.add({'package': pkg, 'title': title, 'text': text});
        }
      }
      return ActionResult.ok(data: {'notifications': notifications, 'count': notifications.length});
    } catch (e) {
      return ActionResult.fail('Get notifications failed: $e');
    }
  }
}
