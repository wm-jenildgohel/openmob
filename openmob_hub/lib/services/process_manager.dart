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

  // --- AiBridge health polling ---

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
          _logService.addLine('hub', 'AiBridge detected');
        }
      }
    } catch (_) {
      final wasRunning =
          _bridgeStatus.value.status == ProcessStatus.running;
      if (wasRunning) {
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
    _bridgeHealthTimer?.cancel();
    _mcpStatus.close();
    _bridgeStatus.close();
  }
}
