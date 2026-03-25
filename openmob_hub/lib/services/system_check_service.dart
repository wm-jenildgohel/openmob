import 'dart:io';
import 'package:rxdart/rxdart.dart';
import '../models/tool_status.dart';

class SystemCheckService {
  final _tools = BehaviorSubject<List<ToolStatus>>.seeded([]);

  ValueStream<List<ToolStatus>> get tools$ => _tools.stream;

  List<ToolStatus> get currentTools => _tools.value;

  Future<void> checkAll() async {
    final results = <ToolStatus>[];

    results.add(await _checkAdb());
    results.add(await _checkNode());
    results.add(await _checkNpm());
    results.add(await _checkAiBridge());

    if (Platform.isMacOS) {
      results.add(await _checkIdb());
    }

    _tools.add(results);
  }

  Future<ToolStatus> _checkAdb() async {
    try {
      final result = await Process.run('adb', ['version']);
      if (result.exitCode == 0) {
        final firstLine = (result.stdout as String).split('\n').first.trim();
        return ToolStatus(
          name: 'ADB',
          available: true,
          version: firstLine,
          installHint: 'Install Android SDK Platform-Tools and add to PATH',
        );
      }
    } catch (_) {}
    return const ToolStatus(
      name: 'ADB',
      available: false,
      installHint: 'Install Android SDK Platform-Tools and add to PATH',
    );
  }

  Future<ToolStatus> _checkNode() async {
    try {
      final result = await Process.run('node', ['--version']);
      if (result.exitCode == 0) {
        final version = (result.stdout as String).trim();
        return ToolStatus(
          name: 'Node.js',
          available: true,
          version: version,
          installHint: 'Install Node.js from https://nodejs.org',
        );
      }
    } catch (_) {}
    return const ToolStatus(
      name: 'Node.js',
      available: false,
      installHint: 'Install Node.js from https://nodejs.org',
    );
  }

  Future<ToolStatus> _checkNpm() async {
    try {
      final result = await Process.run('npm', ['--version']);
      if (result.exitCode == 0) {
        final version = (result.stdout as String).trim();
        return ToolStatus(
          name: 'npm',
          available: true,
          version: version,
          installHint: 'npm is included with Node.js',
        );
      }
    } catch (_) {}
    return const ToolStatus(
      name: 'npm',
      available: false,
      installHint: 'npm is included with Node.js',
    );
  }

  Future<ToolStatus> _checkAiBridge() async {
    try {
      // Walk up from current directory to find project root
      var dir = Directory.current;
      String? bridgePath;
      for (var i = 0; i < 5; i++) {
        final candidate = '${dir.path}/openmob_bridge/target/release/aibridge';
        if (File(candidate).existsSync()) {
          bridgePath = candidate;
          break;
        }
        dir = dir.parent;
      }

      if (bridgePath != null) {
        try {
          final result = await Process.run(bridgePath, ['--version']);
          final version = (result.stdout as String).trim();
          return ToolStatus(
            name: 'AiBridge',
            available: true,
            version: version.isNotEmpty ? version : null,
            path: bridgePath,
            installHint: 'Run: cd openmob_bridge && cargo build --release',
          );
        } catch (_) {
          return ToolStatus(
            name: 'AiBridge',
            available: true,
            path: bridgePath,
            installHint: 'Run: cd openmob_bridge && cargo build --release',
          );
        }
      }
    } catch (_) {}
    return const ToolStatus(
      name: 'AiBridge',
      available: false,
      installHint: 'Run: cd openmob_bridge && cargo build --release',
    );
  }

  Future<ToolStatus> _checkIdb() async {
    try {
      final result = await Process.run('idb', ['--help']);
      if (result.exitCode == 0) {
        return const ToolStatus(
          name: 'idb',
          available: true,
          installHint: 'Install via: brew install idb-companion',
        );
      }
    } catch (_) {}
    return const ToolStatus(
      name: 'idb',
      available: false,
      installHint: 'Install via: brew install idb-companion',
    );
  }

  void dispose() {
    _tools.close();
  }
}
