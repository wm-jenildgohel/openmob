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
      default:
        return ActionResult.fail('Unknown gesture type: $type');
    }
  }
}
