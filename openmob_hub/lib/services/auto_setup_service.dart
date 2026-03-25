import 'dart:io';

import 'package:rxdart/rxdart.dart';

import 'system_check_service.dart';
import 'ai_tool_setup_service.dart';
import 'log_service.dart';
import 'process_manager.dart';

enum SetupPhase {
  checking,
  installingAdb,
  installingNode,
  buildingMcp,
  configuringAiTools,
  startingServices,
  complete,
  failed,
}

class SetupStatus {
  final SetupPhase phase;
  final String message;
  final double progress;
  final bool needsRestart;

  const SetupStatus({
    this.phase = SetupPhase.checking,
    this.message = 'Checking system...',
    this.progress = 0.0,
    this.needsRestart = false,
  });
}

class AutoSetupService {
  final SystemCheckService _systemCheck;
  final AiToolSetupService _aiToolSetup;
  final ProcessManager _processManager;
  final LogService _logService;

  AutoSetupService(
    this._systemCheck,
    this._aiToolSetup,
    this._processManager,
    this._logService,
  );

  final _status = BehaviorSubject<SetupStatus>.seeded(const SetupStatus());
  ValueStream<SetupStatus> get status$ => _status.stream;

  bool _setupComplete = false;
  bool get isComplete => _setupComplete;

  Future<void> runAutoSetup() async {
    _log('Starting auto-setup...');

    // Phase 1: Check what's installed
    _emit(SetupPhase.checking, 'Checking installed tools...', 0.05);
    await _systemCheck.checkAll();
    await Future.delayed(const Duration(milliseconds: 300));

    final tools = _systemCheck.currentTools;
    final adb = tools.where((t) => t.name == 'ADB').firstOrNull;
    final mcp = tools.where((t) => t.name == 'MCP Server').firstOrNull;

    // Phase 2: Install ADB if missing
    if (adb != null && !adb.available) {
      _emit(SetupPhase.installingAdb, 'Downloading Android tools...', 0.15);
      _log('ADB not found — installing...');
      final success = await _systemCheck.installAdb();
      if (!success) {
        _log('ADB install failed — continuing without it', error: true);
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Phase 3: Install Node.js + build MCP if missing
    if (mcp != null && !mcp.available) {
      // Check if Node.js is available
      bool hasNode = false;
      try {
        final result = await Process.run(
          Platform.isWindows ? 'where' : 'which',
          ['node'],
        );
        hasNode = result.exitCode == 0;
      } catch (_) {}

      if (!hasNode) {
        _emit(SetupPhase.installingNode, 'Installing Node.js...', 0.35);
        _log('Node.js not found — installing...');
        final success = await _systemCheck.installNode();
        if (!success) {
          _log('Node.js install failed', error: true);
          // On Windows winget might need a restart
          if (Platform.isWindows) {
            _emit(SetupPhase.complete, 'Node.js installed — restart the app to continue setup', 1.0);
            _status.add(const SetupStatus(
              phase: SetupPhase.complete,
              message: 'Restart the app to complete setup',
              progress: 1.0,
              needsRestart: true,
            ));
            _setupComplete = true;
            return;
          }
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Try to build MCP if project source exists
      final mcpDir = _findMcpDir();
      if (mcpDir != null) {
        _emit(SetupPhase.buildingMcp, 'Setting up MCP Server...', 0.55);
        _log('Building MCP Server...');
        await _buildMcp(mcpDir);
      }
    }

    // Phase 4: Configure AI tools + install skills
    _emit(SetupPhase.configuringAiTools, 'Setting up AI tools...', 0.70);
    await _aiToolSetup.detectAll();

    // Always install — configures MCP + installs skill files for all detected tools
    _log('Configuring AI tools and installing skills...');
    await _aiToolSetup.installAll();
    await Future.delayed(const Duration(milliseconds: 300));

    // Phase 5: Start MCP server if available
    _emit(SetupPhase.startingServices, 'Starting services...', 0.85);
    await _systemCheck.checkAll(); // refresh status after installs
    final mcpNow = _systemCheck.currentTools
        .where((t) => t.name == 'MCP Server')
        .firstOrNull;
    if (mcpNow != null && mcpNow.available) {
      try {
        await _processManager.startMcp();
      } catch (e) {
        _log('MCP auto-start failed: $e', error: true);
      }
    }

    // Done
    _emit(SetupPhase.complete, 'Ready', 1.0);
    _setupComplete = true;
    _log('Auto-setup complete');
  }

  String? _findMcpDir() {
    final sep = Platform.pathSeparator;
    var dir = Directory.current;
    for (var i = 0; i < 5; i++) {
      final candidate = '${dir.path}${sep}openmob_mcp${sep}package.json';
      if (File(candidate).existsSync()) {
        return '${dir.path}${sep}openmob_mcp';
      }
      dir = dir.parent;
    }
    return null;
  }

  Future<void> _buildMcp(String mcpDir) async {
    try {
      // npm install
      _log('Running npm install...');
      final installResult = await Process.run(
        Platform.isWindows ? 'npm.cmd' : 'npm',
        ['install'],
        workingDirectory: mcpDir,
      );
      if (installResult.exitCode != 0) {
        _log('npm install failed: ${installResult.stderr}', error: true);
        return;
      }

      // npm run build
      _log('Running npm run build...');
      final buildResult = await Process.run(
        Platform.isWindows ? 'npm.cmd' : 'npm',
        ['run', 'build'],
        workingDirectory: mcpDir,
      );
      if (buildResult.exitCode != 0) {
        _log('npm build failed: ${buildResult.stderr}', error: true);
        return;
      }

      _log('MCP Server built successfully');
    } catch (e) {
      _log('MCP build error: $e', error: true);
    }
  }

  void _emit(SetupPhase phase, String message, double progress) {
    _status.add(SetupStatus(phase: phase, message: message, progress: progress));
  }

  void _log(String message, {bool error = false}) {
    _logService.addLine(
      'hub',
      message,
      level: error ? LogLevel.error : LogLevel.info,
    );
  }

  void dispose() {
    _status.close();
  }
}
