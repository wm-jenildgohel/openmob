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
    return '$home${_sep}.openmob${_sep}tools';
  }

  /// App executable directory (where bundled tools live)
  String get _bundledDir {
    final exe = Platform.resolvedExecutable;
    return File(exe).parent.path;
  }

  String get _sep => Platform.pathSeparator;

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
        ? '$_bundledDir${_sep}platform-tools${_sep}adb.exe'
        : '$_bundledDir${_sep}platform-tools${_sep}adb';
    if (File(bundledAdb).existsSync()) {
      _resolvedAdbPath = bundledAdb;
      return await _verifyAdb(bundledAdb, 'bundled');
    }

    // 2. Check downloaded (~/.openmob/tools/)
    final downloadedAdb = Platform.isWindows
        ? '$_toolsDir${_sep}platform-tools${_sep}adb.exe'
        : '$_toolsDir${_sep}platform-tools${_sep}adb';
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
        final systemPath = (whichResult.stdout as String).trim().split('\n').first.trim();
        _resolvedAdbPath = systemPath.isNotEmpty ? systemPath : 'adb';
        return ToolStatus(
          name: 'ADB',
          available: true,
          version: 'Ready',
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
      if (result.exitCode != 0) throw Exception('non-zero exit');
      return ToolStatus(
        name: 'ADB',
        available: true,
        version: 'Ready',
        path: path,
        installHint: '',
      );
    } catch (e) {
      _log('ADB found at $path but failed to run: $e', error: true);
      return const ToolStatus(
        name: 'ADB',
        available: false,
        installHint: 'Found but unable to start — click Install to fix',
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
      final dir = Directory('$_toolsDir${_sep}platform-tools');
      await dir.create(recursive: true);
      final zipFile = File('$_toolsDir${_sep}platform-tools.zip');
      await zipFile.writeAsBytes(response.bodyBytes);

      _updateToolStatus('ADB', installing: true, progress: 0.7);

      // Extract
      _log('Extracting platform-tools...');
      ProcessResult extractResult;
      if (Platform.isWindows) {
        // Quote paths for PowerShell to handle spaces in paths
        extractResult = await Process.run(
          'powershell',
          ['-Command', 'Expand-Archive', '-Path', '"${zipFile.path}"', '-DestinationPath', '"$_toolsDir"', '-Force'],
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
        await Process.run('chmod', ['+x', '$_toolsDir${_sep}platform-tools${_sep}adb']);
      }

      _updateToolStatus('ADB', installing: true, progress: 0.9);

      // Verify
      final adbPath = Platform.isWindows
          ? '$_toolsDir${_sep}platform-tools${_sep}adb.exe'
          : '$_toolsDir${_sep}platform-tools${_sep}adb';

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

  /// Install Node.js (needed for MCP server if not bundled as binary)
  Future<bool> installNode() async {
    _updateToolStatus('MCP Server', installing: true, progress: 0.0);
    _log('Installing Node.js...');

    try {
      if (Platform.isWindows) {
        // Try winget first, then fall back to direct MSI download
        bool installed = false;
        try {
          final wingetCheck = await Process.run('winget', ['--version']);
          if (wingetCheck.exitCode == 0) {
            _updateToolStatus('MCP Server', installing: true, progress: 0.3);
            _log('Installing Node.js via winget...');
            final result = await Process.run(
              'winget',
              ['install', '--id', 'OpenJS.NodeJS.LTS', '-e', '--accept-package-agreements', '--accept-source-agreements'],
            );
            installed = result.exitCode == 0;
            if (!installed) {
              _log('winget install failed — trying direct download...', error: true);
            }
          }
        } catch (_) {
          _log('winget not available — trying direct download...');
        }

        // Fallback: download Node.js MSI directly
        if (!installed) {
          _updateToolStatus('MCP Server', installing: true, progress: 0.2);
          _log('Downloading Node.js from nodejs.org...');
          try {
            final nodeDir = Directory('$_toolsDir${_sep}node');
            await nodeDir.create(recursive: true);
            final msiUrl = 'https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi';
            final msiFile = File('$_toolsDir${_sep}node-installer.msi');
            final response = await http.get(Uri.parse(msiUrl));
            if (response.statusCode == 200) {
              await msiFile.writeAsBytes(response.bodyBytes);
              _updateToolStatus('MCP Server', installing: true, progress: 0.6);
              _log('Running Node.js installer...');
              final installResult = await Process.run(
                'msiexec',
                ['/i', msiFile.path, '/qn', '/norestart', 'INSTALLDIR=${nodeDir.path}'],
              );
              if (installResult.exitCode == 0) {
                installed = true;
                _log('Node.js installed to ${nodeDir.path}');
              } else {
                // MSI silent install may need admin — try opening it for user
                _log('Silent install needs admin. Opening installer for you...');
                await Process.run('msiexec', ['/i', msiFile.path]);
                installed = true; // User ran the installer
              }
              await msiFile.delete().catchError((_) => msiFile);
            } else {
              _log('Download failed (HTTP ${response.statusCode})', error: true);
            }
          } catch (e) {
            _log('Direct download failed: $e', error: true);
          }
        }

        if (!installed) {
          _updateToolStatus('MCP Server', installing: false);
          return false;
        }
      } else if (Platform.isLinux) {
        // Download Node.js binary
        _updateToolStatus('MCP Server', installing: true, progress: 0.2);
        final response = await http.get(Uri.parse('https://nodejs.org/dist/v20.18.0/node-v20.18.0-linux-x64.tar.xz'));
        if (response.statusCode != 200) {
          _log('Node.js download failed', error: true);
          _updateToolStatus('MCP Server', installing: false);
          return false;
        }
        _updateToolStatus('MCP Server', installing: true, progress: 0.6);
        final nodeDir = Directory('$_toolsDir${_sep}node');
        await nodeDir.create(recursive: true);
        final archive = File('$_toolsDir${_sep}node.tar.xz');
        await archive.writeAsBytes(response.bodyBytes);
        await Process.run('tar', ['-xf', archive.path, '-C', nodeDir.path, '--strip-components=1']);
        await archive.delete();
      } else if (Platform.isMacOS) {
        final result = await Process.run('brew', ['install', 'node@20']);
        if (result.exitCode != 0) {
          _log('brew install failed: ${result.stderr}', error: true);
          _updateToolStatus('MCP Server', installing: false);
          return false;
        }
      }

      _log('Node.js installed');
      _updateToolStatus('MCP Server', installing: true, progress: 0.7);

      // Now try to build MCP from source if project exists
      await _buildMcpIfSourceExists();

      _updateToolStatus('MCP Server', installing: false, progress: 1.0);
      await checkAll();
      return true;
    } catch (e) {
      _log('Node.js install failed: $e', error: true);
      _updateToolStatus('MCP Server', installing: false);
      return false;
    }
  }

  /// Install AiBridge — copy from project build or download from GitHub releases
  Future<bool> installAiBridge() async {
    _updateToolStatus('AiBridge', installing: true, progress: 0.0);
    _log('Installing AiBridge...');

    try {
      final sep = Platform.pathSeparator;
      final dir = Directory(_toolsDir);
      await dir.create(recursive: true);
      final binaryName = Platform.isWindows ? 'aibridge.exe' : 'aibridge';
      final destFile = File('$_toolsDir$sep$binaryName');

      // 1. Try to copy from project build directory first
      _updateToolStatus('AiBridge', installing: true, progress: 0.2);
      var searchDir = Directory.current;
      for (var i = 0; i < 5; i++) {
        final candidate = Platform.isWindows
            ? '${searchDir.path}${sep}openmob_bridge${sep}target${sep}release${sep}aibridge.exe'
            : '${searchDir.path}${sep}openmob_bridge${sep}target${sep}release${sep}aibridge';
        if (File(candidate).existsSync()) {
          await File(candidate).copy(destFile.path);
          if (!Platform.isWindows) {
            await Process.run('chmod', ['+x', destFile.path]);
          }
          _log('AiBridge copied from project build');
          _updateToolStatus('AiBridge', installing: false, progress: 1.0);
          await checkAll();
          return true;
        }
        searchDir = searchDir.parent;
      }

      // 2. Try downloading from GitHub releases
      _updateToolStatus('AiBridge', installing: true, progress: 0.3);
      final url = _aiBridgeDownloadUrl;
      if (url == null) {
        _log('No download available for this platform', error: true);
        _updateToolError('AiBridge', 'Not available for this platform');
        return false;
      }

      _log('Downloading from GitHub releases...');
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
        onTimeout: () => http.Response('timeout', 408),
      );

      if (response.statusCode == 404) {
        _log('No release found on GitHub', error: true);
        _updateToolError('AiBridge', 'No release available yet — this is optional');
        return false;
      }

      if (response.statusCode != 200) {
        _log('Download failed: HTTP ${response.statusCode}', error: true);
        _updateToolError('AiBridge', 'Download failed — check your internet connection');
        return false;
      }

      if (response.bodyBytes.length < 1000) {
        _log('Downloaded file too small — likely an error page', error: true);
        _updateToolError('AiBridge', 'Download failed — no release available yet');
        return false;
      }

      _updateToolStatus('AiBridge', installing: true, progress: 0.7);
      await destFile.writeAsBytes(response.bodyBytes);

      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', destFile.path]);
      }

      _log('AiBridge installed successfully');
      _updateToolStatus('AiBridge', installing: false, progress: 1.0);
      await checkAll();
      return true;
    } catch (e) {
      _log('AiBridge install failed: $e', error: true);
      _updateToolError('AiBridge', 'Installation failed — this tool is optional');
      return false;
    }
  }

  String? get _aiBridgeDownloadUrl {
    const base = 'https://github.com/wm-jenildgohel/openmob/releases/latest/download';
    if (Platform.isWindows) return '$base/aibridge-windows-x64.exe';
    if (Platform.isLinux) return '$base/aibridge-linux-x64';
    if (Platform.isMacOS) return '$base/aibridge-macos-x64';
    return null;
  }

  // ─── scrcpy (screen mirroring) ───

  Future<ToolStatus> _checkScrcpy() async {
    try {
      final result = await Process.run('scrcpy', ['--version']);
      if (result.exitCode == 0) {
        return const ToolStatus(
          name: 'scrcpy',
          available: true,
          version: 'Ready',
          installHint: '',
        );
      }
    } catch (_) {}

    return const ToolStatus(
      name: 'scrcpy',
      available: false,
      installHint: 'Optional — faster screen preview',
      canAutoInstall: false,
    );
  }

  // ─── MCP Server ───

  Future<ToolStatus> _checkMcpServer() async {
    // 1. Check bundled binary (next to app)
    final bundledMcp = Platform.isWindows
        ? '$_bundledDir${_sep}openmob-mcp.exe'
        : '$_bundledDir${_sep}openmob-mcp';
    if (File(bundledMcp).existsSync()) {
      return ToolStatus(
        name: 'MCP Server',
        available: true,
        version: 'Ready',
        path: bundledMcp,
        installHint: '',
      );
    }

    // 2. Check project build
    var dir = Directory.current;
    for (var i = 0; i < 5; i++) {
      final sep = Platform.pathSeparator;
      final candidate = '${dir.path}${sep}openmob_mcp${sep}build${sep}app${sep}index.js';
      if (File(candidate).existsSync()) {
        return ToolStatus(
          name: 'MCP Server',
          available: true,
          version: 'Ready',
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
        _log('Node.js ${(result.stdout as String).trim()} found — needs MCP build');
        return const ToolStatus(
          name: 'MCP Server',
          available: false,
          version: 'Needs setup',
          installHint: 'Needs setup — click Install',
          canAutoInstall: true,
        );
      }
    } catch (_) {}

    return const ToolStatus(
      name: 'MCP Server',
      available: false,
      installHint: 'Not installed — click Install',
      canAutoInstall: true,
    );
  }

  // ─── AiBridge ───

  Future<ToolStatus> _checkAiBridge() async {
    // 1. Check bundled (next to app)
    final bundledBridge = Platform.isWindows
        ? '$_bundledDir${_sep}aibridge.exe'
        : '$_bundledDir${_sep}aibridge';
    if (File(bundledBridge).existsSync()) {
      return ToolStatus(
        name: 'AiBridge',
        available: true,
        version: 'Ready',
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
          version: 'Ready',
          path: path,
          installHint: '',
        );
      }
    } catch (_) {}

    // 3. Check project build
    final sep = Platform.pathSeparator;
    var dir = Directory.current;
    for (var i = 0; i < 5; i++) {
      final candidate = Platform.isWindows
          ? '${dir.path}${sep}openmob_bridge${sep}target${sep}release${sep}aibridge.exe'
          : '${dir.path}${sep}openmob_bridge${sep}target${sep}release${sep}aibridge';
      if (File(candidate).existsSync()) {
        return ToolStatus(
          name: 'AiBridge',
          available: true,
          version: 'Ready',
          path: candidate,
          installHint: '',
        );
      }
      dir = dir.parent;
    }

    // 4. Check downloaded (~/.openmob/tools/)
    final downloadedBridge = Platform.isWindows
        ? '$_toolsDir${sep}aibridge.exe'
        : '$_toolsDir${sep}aibridge';
    if (File(downloadedBridge).existsSync()) {
      return ToolStatus(
        name: 'AiBridge',
        available: true,
        version: 'Ready',
        path: downloadedBridge,
        installHint: '',
      );
    }

    return const ToolStatus(
      name: 'AiBridge',
      available: false,
      installHint: 'Optional — not required for device testing',
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
          version: 'Ready',
          installHint: '',
        );
      }
    } catch (_) {}
    return const ToolStatus(
      name: 'idb',
      available: false,
      installHint: 'Optional — needed for iOS Simulator testing',
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

  void _updateToolError(String name, String message) {
    final updated = currentTools.map((t) {
      if (t.name == name) {
        return ToolStatus(
          name: t.name,
          available: false,
          installHint: message,
          canAutoInstall: t.canAutoInstall,
          installing: false,
        );
      }
      return t;
    }).toList();
    _tools.add(updated);
  }

  Future<void> _buildMcpIfSourceExists() async {
    final sep = Platform.pathSeparator;
    var dir = Directory.current;
    for (var i = 0; i < 5; i++) {
      final packageJson = '${dir.path}${sep}openmob_mcp${sep}package.json';
      if (File(packageJson).existsSync()) {
        final mcpDir = '${dir.path}${sep}openmob_mcp';
        _log('Found MCP source at $mcpDir — building...');
        try {
          final npm = Platform.isWindows ? 'npm.cmd' : 'npm';
          final install = await Process.run(npm, ['install'], workingDirectory: mcpDir);
          if (install.exitCode != 0) {
            _log('npm install failed: ${install.stderr}', error: true);
            return;
          }
          final build = await Process.run(npm, ['run', 'build'], workingDirectory: mcpDir);
          if (build.exitCode != 0) {
            _log('npm build failed: ${build.stderr}', error: true);
            return;
          }
          _log('MCP Server built successfully');
        } catch (e) {
          _log('MCP build error: $e', error: true);
        }
        return;
      }
      dir = dir.parent;
    }
    _log('MCP source not found — skipping build');
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
