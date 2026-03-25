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

  ValueStream<ProcessInfo> get mcpStatus$ => _mcpStatus.stream;
  ValueStream<ProcessInfo> get bridgeStatus$ => _bridgeStatus.stream;

  // --- Path resolution ---

  String get _projectRoot {
    var dir = Directory.current;
    for (var i = 0; i < 5; i++) {
      final mcpDir = Directory('${dir.path}/openmob_mcp');
      final bridgeDir = Directory('${dir.path}/openmob_bridge');
      if (mcpDir.existsSync() && bridgeDir.existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    return Directory.current.parent.path;
  }

  String get _mcpDir => '$_projectRoot/openmob_mcp';

  // --- MCP Server lifecycle ---

  Future<void> startMcp() async {
    if (_mcpStatus.value.status == ProcessStatus.running) return;

    _mcpStatus.add(_mcpStatus.value.copyWith(status: ProcessStatus.starting));

    try {
      _mcpProcess = await Process.start(
        'node',
        ['build/app/index.js'],
        workingDirectory: _mcpDir,
      );

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
          _mcpStatus.add(ProcessInfo(
            name: 'MCP Server',
            status: ProcessStatus.error,
            errorMessage: 'Exited with code $code',
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
      _mcpStatus.add(ProcessInfo(
        name: 'MCP Server',
        status: ProcessStatus.error,
        errorMessage: e.toString(),
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
    // Check common locations for the aibridge binary
    final candidates = [
      '$_projectRoot/openmob_bridge/target/release/aibridge',
      '$_projectRoot/openmob_bridge/target/debug/aibridge',
    ];

    // Also check PATH via `which`
    try {
      final result = Process.runSync('which', ['aibridge']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty) return path;
      }
    } catch (_) {}

    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  /// Returns list of available AI agents found in PATH
  List<String> get availableAgents {
    final agents = <String>[];
    for (final name in ['claude', 'codex', 'gemini']) {
      try {
        final result = Process.runSync('which', [name]);
        if (result.exitCode == 0) agents.add(name);
      } catch (_) {}
    }
    return agents;
  }

  Future<void> startBridge({String agent = 'claude', int port = 9999}) async {
    if (_bridgeStatus.value.status == ProcessStatus.running) return;

    final binary = _bridgeBinary;
    if (binary == null) {
      _bridgeStatus.add(const ProcessInfo(
        name: 'AiBridge',
        status: ProcessStatus.error,
        errorMessage: 'aibridge binary not found. Build it:\ncd openmob_bridge && cargo build --release',
      ));
      _logService.addLine('hub', 'AiBridge binary not found', level: LogLevel.error);
      return;
    }

    // Validate the agent command exists in PATH
    try {
      final result = Process.runSync('which', [agent]);
      if (result.exitCode != 0) {
        _bridgeStatus.add(ProcessInfo(
          name: 'AiBridge',
          status: ProcessStatus.error,
          errorMessage: '"$agent" not found in PATH.\nInstall it first or choose a different agent.',
        ));
        _logService.addLine('hub', 'Agent "$agent" not found in PATH', level: LogLevel.error);
        return;
      }
    } catch (_) {
      // `which` not available — try starting anyway
    }

    _bridgeStatus.add(_bridgeStatus.value.copyWith(status: ProcessStatus.starting));

    try {
      _bridgeProcess = await Process.start(
        binary,
        ['--port', '$port', '--', agent],
        environment: {'TERM': 'xterm-256color'},
      );

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
        status: ProcessStatus.running,
        pid: _bridgeProcess!.pid,
        startedAt: DateTime.now(),
      ));

      _logService.addLine('hub', 'AiBridge started with $agent (PID: ${_bridgeProcess!.pid}, port: $port)');

      _bridgeProcess!.exitCode.then((code) {
        if (_bridgeStatus.value.status == ProcessStatus.running) {
          _bridgeStatus.add(ProcessInfo(
            name: 'AiBridge',
            status: code == 0 ? ProcessStatus.stopped : ProcessStatus.error,
            errorMessage: code != 0 ? 'Exited with code $code' : null,
          ));
          _logService.addLine(
            'hub',
            'AiBridge exited with code $code',
            level: code != 0 ? LogLevel.error : LogLevel.info,
          );
        }
        _bridgeProcess = null;
      });
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
      _bridgeProcess!.kill();
      try {
        await _bridgeProcess!.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        _bridgeProcess!.kill(ProcessSignal.sigkill);
      }
      _bridgeProcess = null;
    }
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
