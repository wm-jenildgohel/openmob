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
    // Run all lookups in parallel using async versions to avoid blocking UI
    final agentsFuture = _detectAgentsAsync();
    final binaryFuture = Future(() => _bridgeBinary);
    final terminalFuture = Future(() => _terminalEmulator);

    final results = await Future.wait([binaryFuture, terminalFuture, agentsFuture]);
    _cachedBridgeBinary = results[0] as String?;
    _cachedTerminal = results[1] as String?;
    _cachedAgents = results[2] as List<String>;
    _cacheReady = true;
  }

  Future<List<String>> _detectAgentsAsync() async {
    final agents = <String>[];
    // Check all agents in parallel
    final results = await Future.wait(
      ['claude', 'codex', 'gemini'].map((name) async {
        try {
          final result = await Process.run(
            Platform.isWindows ? 'where' : 'which',
            [name],
          );
          return result.exitCode == 0 ? name : null;
        } catch (_) {
          return null;
        }
      }),
    );
    agents.addAll(results.whereType<String>());
    return agents;
  }

  // Sync fallback for cached access
  List<String> _detectAgents() {
    if (_cachedAgents != null) return _cachedAgents!;
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
      // Try bundled binary (next to exe, in tools/ subdir, or ~/.openmob/tools/)
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
      final downloadedMcp = Platform.isWindows
          ? '$home$_sep.openmob${_sep}tools${_sep}openmob-mcp.exe'
          : '$home$_sep.openmob${_sep}tools${_sep}openmob-mcp';

      final mcpBin = [bundledMcpAlt, bundledMcp, downloadedMcp]
          .where((p) => File(p).existsSync())
          .firstOrNull;

      if (mcpBin != null) {
        _mcpProcess = await Process.start(mcpBin, []);
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
      _mcpProcess!.kill(); // On Windows, this already calls TerminateProcess (force kill)
      try {
        await _mcpProcess!.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        // Fallback force kill — use platform-safe approach
        if (!Platform.isWindows) {
          _mcpProcess!.kill(ProcessSignal.sigkill);
        }
        // On Windows, .kill() already did TerminateProcess — nothing more to do
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

    // Check agent exists
    final agents = availableAgents;
    if (agents.isEmpty) {
      _bridgeStatus.add(const ProcessInfo(
        name: 'AiBridge',
        status: ProcessStatus.error,
        errorMessage: 'No AI agents found — install Claude Code, Codex, or Gemini CLI first',
      ));
      _logService.addLine('hub', 'No AI agents (claude/codex/gemini) found in PATH', level: LogLevel.error);
      return;
    }
    if (!agents.contains(agent)) {
      _bridgeStatus.add(ProcessInfo(
        name: 'AiBridge',
        status: ProcessStatus.error,
        errorMessage: '"$agent" not found — available: ${agents.join(", ")}',
      ));
      _logService.addLine('hub', 'Agent "$agent" not found', level: LogLevel.error);
      return;
    }

    _activeBridgePort = port;
    _bridgeStatus.add(_bridgeStatus.value.copyWith(status: ProcessStatus.starting));

    try {
      if (Platform.isWindows) {
        // Open a real terminal window so user can interact with the AI agent
        // Try Windows Terminal (wt) first, fall back to cmd.exe
        final hasWt = _cacheReady ? (_cachedTerminal == 'wt') : _terminalEmulator == 'wt';
        final pauseCmd = '& echo. & echo AiBridge exited. Press any key to close. & pause >nul';

        if (hasWt) {
          // Windows Terminal: new tab with title
          _bridgeProcess = await Process.start('wt', [
            '--title', 'AiBridge ($agent)',
            'cmd', '/c', '"$binary" --port $port -- $agent $pauseCmd',
          ]);
        } else {
          // cmd.exe: /k keeps window open, /c with pause keeps it open after exit
          _bridgeProcess = await Process.start('cmd', [
            '/c', 'title AiBridge ($agent) & "$binary" --port $port -- $agent $pauseCmd',
          ]);
        }
      } else {
        // On Unix, open a terminal window so user can interact with the agent
        final terminal = _cacheReady ? _cachedTerminal : _terminalEmulator;
        final bridgeCmd = '$binary --port $port -- $agent';

        if (terminal != null) {
          final List<String> termArgs;
          final pauseCmd = 'echo "\\nAiBridge exited. Press Enter to close."; read';
          switch (terminal) {
            case 'gnome-terminal':
              termArgs = ['gnome-terminal', '--title', 'AiBridge ($agent)', '--', 'bash', '-c', '$bridgeCmd; $pauseCmd'];
            case 'konsole':
              termArgs = ['konsole', '--title', 'AiBridge ($agent)', '-e', 'bash', '-c', '$bridgeCmd; $pauseCmd'];
            case 'alacritty':
              termArgs = ['alacritty', '--title', 'AiBridge ($agent)', '-e', 'bash', '-c', '$bridgeCmd; $pauseCmd'];
            case 'kitty':
              termArgs = ['kitty', '--title', 'AiBridge ($agent)', 'bash', '-c', '$bridgeCmd; $pauseCmd'];
            default:
              termArgs = [terminal, '-e', 'bash', '-c', bridgeCmd];
          }
          _bridgeProcess = await Process.start(termArgs.first, termArgs.sublist(1));
        } else {
          // No terminal found — run directly (output goes to Hub logs)
          _bridgeProcess = await Process.start(binary, ['--port', '$port', '--', agent]);
        }
      }

      // Capture stdout/stderr in Hub log viewer
      _bridgeProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logService.addLine('aibridge', line);
      });
      _bridgeProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _logService.addLine('aibridge', line, level: LogLevel.warning);
      });

      _bridgeStatus.add(ProcessInfo(
        name: 'AiBridge',
        status: ProcessStatus.starting,
        pid: _bridgeProcess!.pid,
        startedAt: DateTime.now(),
      ));

      _logService.addLine('hub', 'AiBridge started with $agent on port $port (PID: ${_bridgeProcess!.pid})');

      // Monitor exit — detect immediate exits vs normal shutdown
      final startTime = DateTime.now();
      _bridgeProcess!.exitCode.then((code) {
        _bridgeProcess = null;
        final elapsed = DateTime.now().difference(startTime);

        if (elapsed.inSeconds < 3) {
          // Exited within 3 seconds — the agent likely failed to start
          final msg = code != 0
              ? 'AiBridge crashed (exit $code) — "$agent" may not support headless mode'
              : '"$agent" exited immediately — it may need a real terminal window.\n'
                'Tip: Open a terminal and run: aibridge --port $port -- $agent';
          _bridgeStatus.add(ProcessInfo(
            name: 'AiBridge',
            status: ProcessStatus.error,
            errorMessage: msg,
          ));
          _logService.addLine('hub', msg, level: LogLevel.warning);
        } else if (code != 0) {
          _bridgeStatus.add(ProcessInfo(
            name: 'AiBridge',
            status: ProcessStatus.error,
            errorMessage: 'Crashed (exit code $code) — check Logs for details',
          ));
          _logService.addLine('hub', 'AiBridge exited with code $code', level: LogLevel.error);
        } else {
          _bridgeStatus.add(const ProcessInfo(
            name: 'AiBridge',
            status: ProcessStatus.stopped,
          ));
          _logService.addLine('hub', 'AiBridge stopped normally');
        }
      });

      // Wait a moment then check health
      await Future.delayed(const Duration(seconds: 1));
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
    if (_bridgeProcess != null) {
      _bridgeProcess!.kill(); // On Windows, this already calls TerminateProcess
      try {
        await _bridgeProcess!.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        if (!Platform.isWindows) {
          _bridgeProcess!.kill(ProcessSignal.sigkill);
        }
      }
      _bridgeProcess = null;
    }

    // Also try to stop any externally running aibridge
    try {
      if (Platform.isWindows) {
        Process.runSync('taskkill', ['/F', '/IM', 'aibridge.exe']);
      } else {
        Process.runSync('pkill', ['-f', 'aibridge.*--port']);
      }
      _logService.addLine('hub', 'AiBridge process terminated');
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

  int _activeBridgePort = 9999;

  // --- AiBridge health polling (detects externally started bridges) ---

  void startBridgeMonitoring() {
    _bridgeHealthTimer?.cancel();
    _bridgeHealthTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollBridgeHealth(),
    );
  }

  Future<void> _pollBridgeHealth() async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:$_activeBridgePort/health'))
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
