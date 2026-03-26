import 'dart:convert';
import 'dart:io';

import '../models/device.dart';

/// Wraps xcrun simctl for iOS Simulator lifecycle and screenshots.
/// Only functional on macOS with Xcode installed.
class SimctlService {
  bool? _available;

  /// Check if xcrun simctl is available on this system.
  /// Result is cached after first check.
  Future<bool> get isAvailable async {
    if (_available != null) return _available!;
    try {
      final result = await Process.run('xcrun', ['simctl', 'help']);
      _available = result.exitCode == 0;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  /// List all available iOS simulators via `xcrun simctl list devices -j`.
  /// Returns Device objects with platform='ios', deviceType='simulator'.
  Future<List<Device>> listSimulators() async {
    try {
      final result = await Process.run(
        'xcrun',
        ['simctl', 'list', 'devices', '-j'],
        stdoutEncoding: utf8,
      );
      if (result.exitCode != 0) return [];

      final json = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      final devicesMap = json['devices'] as Map<String, dynamic>? ?? {};
      final simulators = <Device>[];

      for (final entry in devicesMap.entries) {
        final runtime = entry.key;
        final devices = entry.value as List? ?? [];
        for (final device in devices) {
          final d = device as Map<String, dynamic>;
          if (d['isAvailable'] == true) {
            simulators.add(Device.fromSimctl(
              udid: d['udid'] as String? ?? '',
              name: d['name'] as String? ?? 'Unknown Simulator',
              state: d['state'] as String? ?? 'Shutdown',
              runtime: runtime,
              deviceTypeId: d['deviceTypeIdentifier'] as String? ?? '',
            ));
          }
        }
      }

      return simulators;
    } catch (_) {
      return [];
    }
  }

  /// Capture a PNG screenshot from a booted simulator.
  /// Uses `xcrun simctl io <udid> screenshot -` to pipe to stdout.
  /// Returns raw PNG bytes.
  Future<List<int>> captureScreenshot(String udid) async {
    final result = await Process.run(
      'xcrun',
      ['simctl', 'io', udid, 'screenshot', '-'],
      stdoutEncoding: null,
    );
    if (result.exitCode != 0) {
      final stderr = result.stderr is String
          ? result.stderr as String
          : String.fromCharCodes(result.stderr as List<int>);
      throw Exception('simctl screenshot failed: $stderr');
    }
    return result.stdout as List<int>;
  }

  /// Launch an app by bundle ID on the simulator.
  Future<void> launchApp(String udid, String bundleId) async {
    final result = await Process.run(
      'xcrun',
      ['simctl', 'launch', udid, bundleId],
    );
    if (result.exitCode != 0) {
      throw Exception('simctl launch failed: ${result.stderr}');
    }
  }

  /// Terminate a running app by bundle ID.
  Future<void> terminateApp(String udid, String bundleId) async {
    final result = await Process.run(
      'xcrun',
      ['simctl', 'terminate', udid, bundleId],
    );
    if (result.exitCode != 0) {
      throw Exception('simctl terminate failed: ${result.stderr}');
    }
  }

  /// Open a URL on the simulator.
  Future<void> openUrl(String udid, String url) async {
    final result = await Process.run(
      'xcrun',
      ['simctl', 'openurl', udid, url],
    );
    if (result.exitCode != 0) {
      throw Exception('simctl openurl failed: ${result.stderr}');
    }
  }

  /// Uninstall an app from the simulator by bundle ID.
  Future<void> uninstallApp(String udid, String bundleId) async {
    final result = await Process.run(
      'xcrun',
      ['simctl', 'uninstall', udid, bundleId],
    );
    if (result.exitCode != 0) {
      throw Exception('simctl uninstall failed: ${result.stderr}');
    }
  }

  /// Boot a simulator by UDID.
  Future<void> bootSimulator(String udid) async {
    final result = await Process.run(
      'xcrun',
      ['simctl', 'boot', udid],
    );
    if (result.exitCode != 0) {
      throw Exception('simctl boot failed: ${result.stderr}');
    }
  }
}
