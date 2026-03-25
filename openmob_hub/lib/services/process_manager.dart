import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

import '../models/process_info.dart';
import 'log_service.dart';

class ProcessManager {
  final LogService _logService;

  ProcessManager(this._logService) {
    startBridgeMonitoring();
    // Pre-cache lookups in background so startBridge() is instant
    _warmCache();
  }

  // MCP Server state
  final _mcpStatus = BehaviorSubject<ProcessInfo>.seeded(
    const ProcessInfo(name: 'MCP Server', status: ProcessStatus.stopped),
  );
  Process? _mcpProcess;

  // AiBridge state
  final _bridgeStatus = BehaviorSubject<ProcessInfo>.seeded(
    const ProcessInfo(name: 'AiBridge', status: ProcessStatus.stopped),
  );
  Process? _bridgeProcess;
  Timer? _bridgeHealthTimer;

  // Cached lookups (populated at startup, used by startBridge instantly)
  String? _cachedBridgeBinary;
  String? _cachedTerminal;
  List<String>? _cachedAgents;
  bool _cacheReady = false;

  Future<void> _warmCache() async {
    // Run all lookups in parallel on a background isolate-like thread
    final results = await Future.wait([
      Future(() => _bridgeBinary),
      Future(() => _terminalEmulator),
      Future(() => _detectAgents()),
    ]);
    _cachedBridgeBinary = results[0] as String?;
    _cachedTerminal = results[1] as String?;
    _cachedAgents = results[2] as List<String>;
    _cacheReady = true;
  }

  List<String> _detectAgents() {
    final agents = <String>[];
    for (final name in ['claude', 'codex', 'gemini']) {
      try {
        final result = Process.runSync(
          Platform.isWindows ? 'where' : 'which',
          [name],
        );
        if (result.exitCode == 0) agents.add(name);
      } catch (_) {}
    }
    return agents;
  }

  ValueStream<ProcessInfo> get mcpStatus$ => _mcpStatus.stream;
  ValueStream<ProcessInfo> get bridgeStatus$ => _bridgeStatus.stream;

  // --- Path resolution ---

  String get _sep => Platform.pathSeparator;

  String? get _projectRoot {
    var dir = Directory.current;
    for (var i = 0; i < 5; i++) {
      final mcpDir = Directory('${dir.path}${_sep}openmob_mcp');
      if (mcpDir.existsSync()) return dir.path;
      dir = dir.parent;
    }
    // Also check next to the executable
    final exeDir = File(Platform.resolvedExecutable).parent.parent;
    final mcpDir = Directory('${exeDir.path}${_sep}openmob_mcp');
    if (mcpDir.existsSync()) return exeDir.path;
    return null;
  }

  String? get _mcpDir {
    final root = _projectRoot;
    if (root == null) return null;
    return '$root${_sep}openmob_mcp';
  }

  // --- MCP Server lifecycle ---

  Future<void> startMcp() async {
    if (_mcpStatus.value.status == ProcessStatus.running) return;

    final mcpDir = _mcpDir;

    // Check bundled binary first (next to app)
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final bundledMcp = Platform.isWindows
        ? '$exeDir${_sep}tools${_sep}openmob-mcp.exe'
        : '$exeDir${_sep}tools${_sep}openmob-mcp';
    final bundledMcpAlt = Platform.isWindows
        ? '$exeDir${_sep}openmob-mcp.exe'
        : '$exeDir${_sep}openmob-mcp';

    _mcpStatus.add(_mcpStatus.value.copyWith(status: ProcessStatus.starting));

    try {
      // Try bundled binary
      if (File(bundledMcp).existsSync() || File(bundledMcpAlt).existsSync()) {
        final bin = File(bundledMcp).existsSync() ? bundledMcp : bundledMcpAlt;
        _mcpProcess = await Process.start(bin, []);
      } else if (mcpDir != null && Directory(mcpDir).existsSync()) {
        // Try project build — but check Node.js first
        final indexJs = '$mcpDir${_sep}build${_sep}app${_sep}index.js';
        if (!File(indexJs).existsSync()) {
          _mcpStatus.add(const ProcessInfo(
            name: 'MCP Server',
            status: ProcessStatus.error,
            errorMessage: 'MCP Server needs setup — go to System Check',
          ));
          _logService.addLine('hub', 'MCP index.js not found at $indexJs', level: LogLevel.error);
          return;
        }
        // Verify Node.js is installed
        try {
          final nodeCheck = Process.runSync(
            Platform.isWindows ? 'where' : 'which',
            ['node'],
          );
          if (nodeCheck.exitCode != 0) throw Exception('not found');
        } catch (_) {
          _mcpStatus.add(const ProcessInfo(
            name: 'MCP Server',
            status: ProcessStatus.error,
            errorMessage: 'Node.js is not installed — go to System Check',
          ));
          _logService.addLine('hub', 'Node.js not found in PATH', level: LogLevel.error);
          return;
        }
        // Use absolute path to avoid Windows path resolution issues
        _mcpProcess = await Process.start('node', [indexJs]);
      } else {
        _mcpStatus.add(const ProcessInfo(
          name: 'MCP Server',
          status: ProcessStatus.error,
          errorMessage: 'MCP Server not found — go to System Check',
        ));
        _logService.addLine('hub', 'MCP directory not found', level: LogLevel.error);
        return;
      }

      _mcpProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logService.addLine('mcp', line);
      });

      _mcpProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logService.addLine('mcp', line, level: LogLevel.warning);
      });

      _mcpStatus.add(ProcessInfo(
        name: 'MCP Server',
        status: ProcessStatus.running,
        pid: _mcpProcess!.pid,
        startedAt: DateTime.now(),
      ));

      _logService.addLine('hub', 'MCP Server started (PID: ${_mcpProcess!.pid})');

      _mcpProcess!.exitCode.then((code) {
        if (code != 0) {
          _mcpStatus.add(const ProcessInfo(
            name: 'MCP Server',
            status: ProcessStatus.error,
            errorMessage: 'Stopped unexpectedly — check System Check',
          ));
          _logService.addLine('hub', 'MCP Server exited with code $code',
              level: LogLevel.error);
        } else {
          _mcpStatus.add(const ProcessInfo(
            name: 'MCP Server',
            status: ProcessStatus.stopped,
          ));
          _logService.addLine('hub', 'MCP Server stopped');
        }
        _mcpProcess = null;
      });
    } catch (e) {
      _mcpStatus.add(const ProcessInfo(
        name: 'MCP Server',
        status: ProcessStatus.error,
        errorMessage: 'Could not start — go to System Check',
      ));
      _logService.addLine('hub', 'Failed to start MCP Server: $e',
          level: LogLevel.error);
    }
  }

  Future<void> stopMcp() async {
    if (_mcpProcess != null) {
      _mcpProcess!.kill();
      try {
        await _mcpProcess!.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        _mcpProcess!.kill(ProcessSignal.sigkill);
      }
      _mcpProcess = null;
    }
    _mcpStatus.add(const ProcessInfo(
      name: 'MCP Server',
      status: ProcessStatus.stopped,
    ));
    _logService.addLine('hub', 'MCP Server stopped');
  }

  Future<void> restartMcp() async {
    await stopMcp();
    await Future.delayed(const Duration(seconds: 1));
    await startMcp();
  }

  // --- AiBridge lifecycle ---

  String? get _bridgeBinary {
    final binaryName = Platform.isWindows ? 'aibridge.exe' : 'aibridge';

    // Check bundled (next to app)
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    for (final subDir in ['tools', '']) {
      final candidate = subDir.isEmpty
          ? '$exeDir$_sep$binaryName'
          : '$exeDir$_sep$subDir$_sep$binaryName';
      if (File(candidate).existsSync()) return candidate;
    }

    // Check PATH
    try {
      final result = Process.runSync(
        Platform.isWindows ? 'where' : 'which',
        ['aibridge'],
      );
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim().split('\n').first;
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}

    // Check downloaded (~/.openmob/tools/)
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ?? '.';
    final downloaded = '$home$_sep.openmob${_sep}tools$_sep$binaryName';
    if (File(downloaded).existsSync()) return downloaded;

    // Check project build
    final root = _projectRoot;
    if (root != null) {
      final candidate = '$root${_sep}openmob_bridge${_sep}target${_sep}release$_sep$binaryName';
      if (File(candidate).existsSync()) return candidate;
    }

    return null;
  }

  /// Returns list of available AI agents found on this computer (uses cache)
  List<String> get availableAgents {
    if (_cachedAgents != null) return _cachedAgents!;
    return _detectAgents();
  }

  /// Detect available terminal emulator on the system
  String? get _terminalEmulator {
    if (Platform.isWindows) {
      // Windows Terminal (wt.exe) is preferred, then cmd.exe as fallback
      for (final term in ['wt', 'cmd']) {
        try {
          final result = Process.runSync('where', [term]);
          if (result.exitCode == 0) return term;
        } catch (_) {}
      }
      return 'cmd'; // cmd.exe is always available on Windows
    }

    final terminals = [
      'gnome-terminal', 'konsole', 'xfce4-terminal', 'mate-terminal',
      'tilix', 'alacritty', 'kitty', 'xterm',
    ];
    for (final term in terminals) {
      try {
        final result = Process.runSync('which', [term]);
        if (result.exitCode == 0) return term;
      } catch (_) {}
    }
    return null;
  }

  Future<void> startBridge({String agent = 'claude', int port = 9999}) async {
    if (_bridgeStatus.value.status == ProcessStatus.running) return;

    // Use cached values for instant startup (pre-warmed at construction)
    final binary = _cacheReady ? _cachedBridgeBinary : _bridgeBinary;
    if (binary == null) {
      _bridgeStatus.add(const ProcessInfo(
        name: 'AiBridge',
        status: ProcessStatus.error,
        errorMessage: 'AiBridge not found — go to System Check',
      ));
      _logService.addLine('hub', 'AiBridge binary not found', level: LogLevel.error);
      return;
    }

    // Check agent from cache (no slow `where` call)
    final agents = availableAgents;
    if (agents.isNotEmpty && !agents.contains(agent)) {
      _bridgeStatus.add(ProcessInfo(
        name: 'AiBridge',
        status: ProcessStatus.error,
        errorMessage: '"$agent" not found — available: ${agents.join(", ")}',
      ));
      _logService.addLine('hub', 'Agent "$agent" not found', level: LogLevel.error);
      return;
    }

    final terminal = _cacheReady ? _cachedTerminal : _terminalEmulator;
    if (terminal == null) {
      _bridgeStatus.add(const ProcessInfo(
        name: 'AiBridge',
        status: ProcessStatus.error,
        errorMessage: 'No terminal found on this system',
      ));
      _logService.addLine('hub', 'No terminal emulator found', level: LogLevel.error);
      return;
    }

    _bridgeStatus.add(_bridgeStatus.value.copyWith(status: ProcessStatus.starting));

    try {
      final List<String> termArgs;

      if (Platform.isWindows) {
        // Windows: use Windows Terminal (wt) or cmd.exe
        if (terminal == 'wt') {
          termArgs = ['wt', '--title', 'AiBridge ($agent)', '--', binary, '--port', '$port', '--', agent];
        } else {
          termArgs = ['cmd', '/c', 'start', 'AiBridge ($agent)', binary, '--port', '$port', '--', agent];
        }
      } else {
        // Unix: use detected terminal
        final bridgeCmd = '$binary --port $port -- $agent';
        switch (terminal) {
          case 'gnome-terminal':
            termArgs = ['gnome-terminal', '--title', 'AiBridge ($agent)', '--', 'bash', '-c', '$bridgeCmd; echo "\\nAiBridge exited. Press Enter to close."; read'];
          case 'konsole':
            termArgs = ['konsole', '--title', 'AiBridge ($agent)', '-e', 'bash', '-c', '$bridgeCmd; echo "\\nAiBridge exited. Press Enter to close."; read'];
          case 'alacritty':
            termArgs = ['alacritty', '--title', 'AiBridge ($agent)', '-e', 'bash', '-c', '$bridgeCmd; echo "\\nAiBridge exited. Press Enter to close."; read'];
          case 'kitty':
            termArgs = ['kitty', '--title', 'AiBridge ($agent)', 'bash', '-c', '$bridgeCmd; echo "\\nAiBridge exited. Press Enter to close."; read'];
          default:
            termArgs = [terminal, '-e', 'bash', '-c', bridgeCmd];
        }
      }

      _bridgeProcess = await Process.start(
        termArgs.first,
        termArgs.sublist(1),
      );

      _bridgeStatus.add(ProcessInfo(
        name: 'AiBridge',
        status: ProcessStatus.starting,
        pid: _bridgeProcess!.pid,
        startedAt: DateTime.now(),
      ));

      _logService.addLine('hub', 'AiBridge launching in $terminal with $agent (port: $port)');

      // Monitor the terminal process — when it exits, bridge is done
      _bridgeProcess!.exitCode.then((code) {
        _bridgeProcess = null;
        // Health polling will detect the actual bridge state
        _logService.addLine('hub', 'AiBridge terminal closed (code: $code)');
      });

      // Quick poll — don't block UI. Health timer handles ongoing detection.
      await Future.delayed(const Duration(milliseconds: 500));
      await _pollBridgeHealth();
    } catch (e) {
      _bridgeStatus.add(ProcessInfo(
        name: 'AiBridge',
        status: ProcessStatus.error,
        errorMessage: e.toString(),
      ));
      _logService.addLine('hub', 'Failed to start AiBridge: $e', level: LogLevel.error);
    }
  }

  Future<void> stopBridge() async {
    // If we launched the terminal, kill it
    if (_bridgeProcess != null) {
      _bridgeProcess!.kill();
      try {
        await _bridgeProcess!.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        _bridgeProcess!.kill(ProcessSignal.sigkill);
      }
      _bridgeProcess = null;
    }

    // Also try to stop any externally running aibridge via its API
    try {
      // AiBridge doesn't have a shutdown endpoint, so we find and kill the process
      final result = Process.runSync('pkill', ['-f', 'aibridge.*--port']);
      if (result.exitCode == 0) {
        _logService.addLine('hub', 'AiBridge process terminated');
      }
    } catch (_) {}

    _bridgeStatus.add(const ProcessInfo(
      name: 'AiBridge',
      status: ProcessStatus.stopped,
    ));
    _logService.addLine('hub', 'AiBridge stopped');
  }

  Future<void> restartBridge({String agent = 'claude', int port = 9999}) async {
    await stopBridge();
    await Future.delayed(const Duration(seconds: 1));
    await startBridge(agent: agent, port: port);
  }

  // --- AiBridge health polling (detects externally started bridges) ---

  void startBridgeMonitoring() {
    _bridgeHealthTimer?.cancel();
    _bridgeHealthTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollBridgeHealth(),
    );
  }

  Future<void> _pollBridgeHealth() async {
    // Skip polling if we started the bridge ourselves
    if (_bridgeProcess != null) return;

    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:9999/health'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final wasRunning =
            _bridgeStatus.value.status == ProcessStatus.running;
        if (!wasRunning) {
          _bridgeStatus.add(ProcessInfo(
            name: 'AiBridge',
            status: ProcessStatus.running,
            startedAt: DateTime.now(),
          ));
          _logService.addLine('hub', 'AiBridge detected (external)');
        }
      }
    } catch (_) {
      final wasRunning =
          _bridgeStatus.value.status == ProcessStatus.running;
      if (wasRunning && _bridgeProcess == null) {
        _bridgeStatus.add(const ProcessInfo(
          name: 'AiBridge',
          status: ProcessStatus.stopped,
        ));
        _logService.addLine('hub', 'AiBridge disconnected',
            level: LogLevel.warning);
      }
    }
  }

  // --- Cleanup ---

  void dispose() {
    _mcpProcess?.kill();
    _bridgeProcess?.kill();
    _bridgeHealthTimer?.cancel();
    _mcpStatus.close();
    _bridgeStatus.close();
  }
}
