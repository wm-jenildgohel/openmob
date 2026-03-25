import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

import '../models/tool_status.dart';
import 'log_service.dart';

class SystemCheckService {
  final LogService? _logService;

  SystemCheckService({LogService? logService}) : _logService = logService;

  final _tools = BehaviorSubject<List<ToolStatus>>.seeded([]);

  ValueStream<List<ToolStatus>> get tools$ => _tools.stream;
  List<ToolStatus> get currentTools => _tools.value;

  /// OpenMob tools directory — bundled + downloaded tools live here
  String get _toolsDir {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$home/.openmob/tools';
  }

  /// Bundled tools directory (next to the app executable)
  String get _bundledDir {
    final exe = Platform.resolvedExecutable;
    return '${File(exe).parent.path}/tools';
  }

  Future<void> checkAll() async {
    final results = <ToolStatus>[];

    results.add(await _checkAdb());
    results.add(await _checkScrcpy());
    results.add(await _checkMcpServer());
    results.add(await _checkAiBridge());

    if (Platform.isMacOS) {
      results.add(await _checkIdb());
    }

    _tools.add(results);
  }

  // ─── ADB ───

  String? _resolvedAdbPath;

  /// Returns the resolved ADB path (bundled, downloaded, or system)
  String? get adbPath => _resolvedAdbPath;

  Future<ToolStatus> _checkAdb() async {
    // 1. Check bundled (next to app)
    final bundledAdb = Platform.isWindows
        ? '$_bundledDir/platform-tools/adb.exe'
        : '$_bundledDir/platform-tools/adb';
    if (File(bundledAdb).existsSync()) {
      _resolvedAdbPath = bundledAdb;
      return await _verifyAdb(bundledAdb, 'bundled');
    }

    // 2. Check downloaded (~/.openmob/tools/)
    final downloadedAdb = Platform.isWindows
        ? '$_toolsDir/platform-tools/adb.exe'
        : '$_toolsDir/platform-tools/adb';
    if (File(downloadedAdb).existsSync()) {
      _resolvedAdbPath = downloadedAdb;
      return await _verifyAdb(downloadedAdb, 'downloaded');
    }

    // 3. Check system PATH
    try {
      final result = await Process.run('adb', ['version']);
      if (result.exitCode == 0) {
        final whichResult = Process.runSync(
          Platform.isWindows ? 'where' : 'which',
          ['adb'],
        );
        final systemPath = (whichResult.stdout as String).trim().split('\n').first;
        _resolvedAdbPath = systemPath.isNotEmpty ? systemPath : 'adb';
        final ver = (result.stdout as String).split('\n').first.trim();
        return ToolStatus(
          name: 'ADB',
          available: true,
          version: ver,
          path: _resolvedAdbPath,
          installHint: '',
          canAutoInstall: false,
        );
      }
    } catch (_) {}

    // Not found — can auto-install
    return const ToolStatus(
      name: 'ADB',
      available: false,
      installHint: 'Required for Android device control',
      canAutoInstall: true,
    );
  }

  Future<ToolStatus> _verifyAdb(String path, String source) async {
    try {
      final result = await Process.run(path, ['version']);
      final ver = (result.stdout as String).split('\n').first.trim();
      return ToolStatus(
        name: 'ADB',
        available: true,
        version: '$ver ($source)',
        path: path,
        installHint: '',
      );
    } catch (e) {
      return ToolStatus(
        name: 'ADB',
        available: false,
        path: path,
        installHint: 'ADB found at $path but failed to run: $e',
        canAutoInstall: true,
      );
    }
  }

  /// Download ADB platform-tools from Google
  Future<bool> installAdb() async {
    _updateToolStatus('ADB', installing: true, progress: 0.0);
    _log('Downloading ADB platform-tools...');

    try {
      final url = _adbDownloadUrl;
      if (url == null) {
        _log('Unsupported platform for ADB auto-install', error: true);
        _updateToolStatus('ADB', installing: false);
        return false;
      }

      // Download
      _updateToolStatus('ADB', installing: true, progress: 0.1);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _log('Download failed: HTTP ${response.statusCode}', error: true);
        _updateToolStatus('ADB', installing: false);
        return false;
      }

      _updateToolStatus('ADB', installing: true, progress: 0.5);

      // Save zip
      final dir = Directory('$_toolsDir/platform-tools');
      await dir.create(recursive: true);
      final zipFile = File('$_toolsDir/platform-tools.zip');
      await zipFile.writeAsBytes(response.bodyBytes);

      _updateToolStatus('ADB', installing: true, progress: 0.7);

      // Extract
      _log('Extracting platform-tools...');
      ProcessResult extractResult;
      if (Platform.isWindows) {
        extractResult = await Process.run(
          'powershell',
          ['-Command', 'Expand-Archive', '-Path', zipFile.path, '-DestinationPath', _toolsDir, '-Force'],
        );
      } else {
        extractResult = await Process.run(
          'unzip', ['-o', zipFile.path, '-d', _toolsDir],
        );
      }

      if (extractResult.exitCode != 0) {
        _log('Extract failed: ${extractResult.stderr}', error: true);
        _updateToolStatus('ADB', installing: false);
        return false;
      }

      // Cleanup zip
      await zipFile.delete();

      // Make executable on Unix
      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', '$_toolsDir/platform-tools/adb']);
      }

      _updateToolStatus('ADB', installing: true, progress: 0.9);

      // Verify
      final adbPath = Platform.isWindows
          ? '$_toolsDir/platform-tools/adb.exe'
          : '$_toolsDir/platform-tools/adb';

      if (!File(adbPath).existsSync()) {
        _log('ADB binary not found after extraction', error: true);
        _updateToolStatus('ADB', installing: false);
        return false;
      }

      _resolvedAdbPath = adbPath;
      _log('ADB installed successfully at $adbPath');
      _updateToolStatus('ADB', installing: false, progress: 1.0);

      // Re-check to update status
      await checkAll();
      return true;
    } catch (e) {
      _log('ADB install failed: $e', error: true);
      _updateToolStatus('ADB', installing: false);
      return false;
    }
  }

  String? get _adbDownloadUrl {
    if (Platform.isWindows) {
      return 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip';
    } else if (Platform.isMacOS) {
      return 'https://dl.google.com/android/repository/platform-tools-latest-darwin.zip';
    } else if (Platform.isLinux) {
      return 'https://dl.google.com/android/repository/platform-tools-latest-linux.zip';
    }
    return null;
  }

  // ─── scrcpy (screen mirroring) ───

  Future<ToolStatus> _checkScrcpy() async {
    try {
      final result = await Process.run('scrcpy', ['--version']);
      if (result.exitCode == 0) {
        final ver = (result.stdout as String).split('\n').first.trim();
        return ToolStatus(
          name: 'scrcpy',
          available: true,
          version: ver,
          installHint: '',
        );
      }
    } catch (_) {}

    return ToolStatus(
      name: 'scrcpy',
      available: false,
      installHint: Platform.isLinux
          ? 'Install: sudo apt install scrcpy'
          : Platform.isMacOS
              ? 'Install: brew install scrcpy'
              : 'Download from https://github.com/Genymobile/scrcpy',
      canAutoInstall: false,
    );
  }

  // ─── MCP Server ───

  Future<ToolStatus> _checkMcpServer() async {
    // 1. Check bundled binary (next to app)
    final bundledMcp = Platform.isWindows
        ? '$_bundledDir/openmob-mcp.exe'
        : '$_bundledDir/openmob-mcp';
    if (File(bundledMcp).existsSync()) {
      return ToolStatus(
        name: 'MCP Server',
        available: true,
        version: 'bundled',
        path: bundledMcp,
        installHint: '',
      );
    }

    // 2. Check project build
    var dir = Directory.current;
    for (var i = 0; i < 5; i++) {
      final candidate = '${dir.path}/openmob_mcp/build/app/index.js';
      if (File(candidate).existsSync()) {
        return ToolStatus(
          name: 'MCP Server',
          available: true,
          version: 'project build',
          path: candidate,
          installHint: '',
        );
      }
      dir = dir.parent;
    }

    // 3. Check if node is available (can run from source)
    try {
      final result = await Process.run('node', ['--version']);
      if (result.exitCode == 0) {
        return ToolStatus(
          name: 'MCP Server',
          available: false,
          version: 'Node.js ${(result.stdout as String).trim()} available',
          installHint: 'Run: cd openmob_mcp && npm install && npm run build',
        );
      }
    } catch (_) {}

    return const ToolStatus(
      name: 'MCP Server',
      available: false,
      installHint: 'MCP Server binary not found. Included in release downloads.',
    );
  }

  // ─── AiBridge ───

  Future<ToolStatus> _checkAiBridge() async {
    // 1. Check bundled (next to app)
    final bundledBridge = Platform.isWindows
        ? '$_bundledDir/aibridge.exe'
        : '$_bundledDir/aibridge';
    if (File(bundledBridge).existsSync()) {
      return ToolStatus(
        name: 'AiBridge',
        available: true,
        version: 'bundled',
        path: bundledBridge,
        installHint: '',
      );
    }

    // 2. Check PATH
    try {
      final result = Process.runSync(
        Platform.isWindows ? 'where' : 'which',
        ['aibridge'],
      );
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim().split('\n').first;
        return ToolStatus(
          name: 'AiBridge',
          available: true,
          path: path,
          installHint: '',
        );
      }
    } catch (_) {}

    // 3. Check project build
    var dir = Directory.current;
    for (var i = 0; i < 5; i++) {
      final candidate = Platform.isWindows
          ? '${dir.path}/openmob_bridge/target/release/aibridge.exe'
          : '${dir.path}/openmob_bridge/target/release/aibridge';
      if (File(candidate).existsSync()) {
        return ToolStatus(
          name: 'AiBridge',
          available: true,
          version: 'project build',
          path: candidate,
          installHint: '',
        );
      }
      dir = dir.parent;
    }

    return const ToolStatus(
      name: 'AiBridge',
      available: false,
      installHint: 'Optional. Included in release downloads or build: cd openmob_bridge && cargo build --release',
    );
  }

  // ─── idb (macOS only) ───

  Future<ToolStatus> _checkIdb() async {
    try {
      final result = await Process.run('idb', ['--help']);
      if (result.exitCode == 0) {
        return const ToolStatus(
          name: 'idb',
          available: true,
          installHint: '',
        );
      }
    } catch (_) {}
    return const ToolStatus(
      name: 'idb',
      available: false,
      installHint: 'Optional (iOS). Install: brew install idb-companion && pip3 install fb-idb',
    );
  }

  // ─── Helpers ───

  void _updateToolStatus(String name, {bool? installing, double? progress}) {
    final updated = currentTools.map((t) {
      if (t.name == name) {
        return t.copyWith(installing: installing, installProgress: progress);
      }
      return t;
    }).toList();
    _tools.add(updated);
  }

  void _log(String message, {bool error = false}) {
    _logService?.addLine(
      'hub',
      message,
      level: error ? LogLevel.error : LogLevel.info,
    );
  }

  void dispose() {
    _tools.close();
  }
}
