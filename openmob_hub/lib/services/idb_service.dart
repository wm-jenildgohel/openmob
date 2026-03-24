import 'dart:convert';
import 'dart:io';

import '../models/ui_node.dart';

/// Wraps facebook/idb for iOS Simulator UI tree inspection and input simulation.
/// Optional dependency -- graceful degradation when not installed.
class IdbService {
  bool? _available;

  /// Check if idb is available on this system.
  /// Result is cached after first check.
  Future<bool> get isAvailable async {
    if (_available != null) return _available!;
    try {
      final result = await Process.run('idb', ['--help']);
      _available = result.exitCode == 0;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  /// Get the full accessibility tree from a simulator.
  /// Uses `idb ui describe-all --udid <udid>`.
  /// Returns UiNode list with sequential indices.
  Future<List<UiNode>> describeAll(String udid) async {
    try {
      final result = await Process.run(
        'idb',
        ['ui', 'describe-all', '--udid', udid],
        stdoutEncoding: utf8,
      );
      if (result.exitCode != 0) return [];

      final parsed = jsonDecode(result.stdout as String);
      if (parsed is! List) return [];

      final nodes = <UiNode>[];
      int index = 0;

      for (final element in parsed) {
        if (element is! Map<String, dynamic>) {
          index++;
          continue;
        }

        // Parse AXFrame: {x, y, width, height} -> Rect bounds
        final frame = element['AXFrame'] as Map<String, dynamic>?;
        int left = 0, top = 0, right = 0, bottom = 0;
        if (frame != null) {
          final x = (frame['x'] as num?)?.toInt() ?? 0;
          final y = (frame['y'] as num?)?.toInt() ?? 0;
          final w = (frame['width'] as num?)?.toInt() ?? 0;
          final h = (frame['height'] as num?)?.toInt() ?? 0;
          left = x;
          top = y;
          right = x + w;
          bottom = y + h;
        }

        final label = element['AXLabel'] as String? ?? '';
        final role = element['role'] as String? ?? '';
        final uniqueId = element['AXUniqueId'] as String? ?? '';

        nodes.add(UiNode(
          index: index,
          text: label,
          className: role,
          resourceId: uniqueId,
          contentDesc: label,
          bounds: Rect(left: left, top: top, right: right, bottom: bottom),
          visible: true,
        ));

        index++;
      }

      return nodes;
    } catch (_) {
      return [];
    }
  }

  /// Tap at coordinates on a simulator.
  Future<void> tap(String udid, int x, int y) async {
    final result = await Process.run(
      'idb',
      ['ui', 'tap', '$x', '$y', '--udid', udid],
    );
    if (result.exitCode != 0) {
      throw Exception('idb tap failed: ${result.stderr}');
    }
  }

  /// Swipe from (x1,y1) to (x2,y2) on a simulator.
  Future<void> swipe(
    String udid,
    int x1,
    int y1,
    int x2,
    int y2, {
    int durationMs = 300,
  }) async {
    final result = await Process.run(
      'idb',
      ['ui', 'swipe', '$x1', '$y1', '$x2', '$y2', '--udid', udid],
    );
    if (result.exitCode != 0) {
      throw Exception('idb swipe failed: ${result.stderr}');
    }
  }

  /// Type text on a simulator.
  Future<void> typeText(String udid, String text) async {
    final result = await Process.run(
      'idb',
      ['ui', 'text', text, '--udid', udid],
    );
    if (result.exitCode != 0) {
      throw Exception('idb typeText failed: ${result.stderr}');
    }
  }

  /// Press a hardware button on a simulator.
  /// Supported buttons: HOME, LOCK, SIDE_BUTTON, SIRI, APPLE_PAY
  Future<void> pressButton(String udid, String button) async {
    final result = await Process.run(
      'idb',
      ['ui', 'button', button, '--udid', udid],
    );
    if (result.exitCode != 0) {
      throw Exception('idb pressButton failed: ${result.stderr}');
    }
  }
}
