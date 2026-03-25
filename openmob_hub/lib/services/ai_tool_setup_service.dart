import 'dart:convert';
import 'dart:io';

import 'package:rxdart/rxdart.dart';

import '../models/ai_tool.dart';
import 'log_service.dart';

class AiToolSetupService {
  final LogService _logService;

  AiToolSetupService(this._logService);

  final _tools = BehaviorSubject<List<AiTool>>.seeded([]);
  ValueStream<List<AiTool>> get tools$ => _tools.stream;
  List<AiTool> get currentTools => _tools.value;

  /// Resolve the MCP server binary/script path
  String get _mcpCommand {
    // Check bundled binary
    final exe = Platform.resolvedExecutable;
    final bundledDir = File(exe).parent.path;
    final bundledBin = Platform.isWindows
        ? '$bundledDir/tools/openmob-mcp.exe'
        : '$bundledDir/tools/openmob-mcp';
    if (File(bundledBin).existsSync()) return bundledBin;

    // Check project build
    var dir = Directory.current;
    for (var i = 0; i < 5; i++) {
      final candidate = '${dir.path}/openmob_mcp/build/app/index.js';
      if (File(candidate).existsSync()) return candidate;
      dir = dir.parent;
    }

    return 'openmob-mcp';
  }

  bool get _mcpIsBinary => !_mcpCommand.endsWith('.js');

  String get _mcpCwd {
    if (_mcpIsBinary) return '';
    final jsPath = _mcpCommand;
    // cwd is openmob_mcp/ (3 levels up from build/app/index.js)
    return File(jsPath).parent.parent.parent.path;
  }

  /// Detect all AI tools and their config status
  Future<void> detectAll() async {
    final results = <AiTool>[];

    results.add(await _detectCursor());
    results.add(await _detectClaudeDesktop());
    results.add(await _detectClaudeCode());
    results.add(await _detectVSCode());

    _tools.add(results);
  }

  // ─── Cursor ───

  String get _cursorConfigPath {
    final home = _homeDir;
    return '$home/.cursor/mcp.json';
  }

  Future<AiTool> _detectCursor() async {
    final path = _cursorConfigPath;
    final detected = _commandExists('cursor') || File(path).existsSync();
    final configured = detected && _hasOpenMobConfig(path);
    return AiTool(
      name: 'Cursor',
      icon: 'cursor',
      detected: detected,
      configured: configured,
      configPath: path,
    );
  }

  Future<bool> installCursor() async {
    return _installMcpConfig(
      'Cursor',
      _cursorConfigPath,
      wrapInMcpServers: true,
    );
  }

  // ─── Claude Desktop ───

  String get _claudeDesktopConfigPath {
    final home = _homeDir;
    if (Platform.isMacOS) {
      return '$home/Library/Application Support/Claude/claude_desktop_config.json';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '$home/AppData/Roaming';
      return '$appData/Claude/claude_desktop_config.json';
    }
    return '$home/.config/Claude/claude_desktop_config.json';
  }

  Future<AiTool> _detectClaudeDesktop() async {
    final path = _claudeDesktopConfigPath;
    final detected = File(path).existsSync() ||
        Directory(File(path).parent.path).existsSync();
    final configured = detected && _hasOpenMobConfig(path);
    return AiTool(
      name: 'Claude Desktop',
      icon: 'claude',
      detected: detected,
      configured: configured,
      configPath: path,
    );
  }

  Future<bool> installClaudeDesktop() async {
    return _installMcpConfig(
      'Claude Desktop',
      _claudeDesktopConfigPath,
      wrapInMcpServers: true,
    );
  }

  // ─── Claude Code ───

  String get _claudeCodeConfigPath {
    final home = _homeDir;
    return '$home/.claude/settings.json';
  }

  Future<AiTool> _detectClaudeCode() async {
    final detected = _commandExists('claude') ||
        File(_claudeCodeConfigPath).existsSync();
    final configured = detected && _hasOpenMobConfig(_claudeCodeConfigPath);
    return AiTool(
      name: 'Claude Code',
      icon: 'claude-code',
      detected: detected,
      configured: configured,
      configPath: _claudeCodeConfigPath,
    );
  }

  Future<bool> installClaudeCode() async {
    return _installMcpConfig(
      'Claude Code',
      _claudeCodeConfigPath,
      wrapInMcpServers: true,
    );
  }

  // ─── VS Code ───

  String get _vscodeConfigDir {
    final home = _homeDir;
    if (Platform.isMacOS) {
      return '$home/Library/Application Support/Code/User';
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'] ?? '$home/AppData/Roaming';
      return '$appData/Code/User';
    }
    return '$home/.config/Code/User';
  }

  Future<AiTool> _detectVSCode() async {
    final detected = _commandExists('code') ||
        Directory(_vscodeConfigDir).existsSync();
    // VS Code MCP config is in .vscode/mcp.json per project, not global
    return AiTool(
      name: 'VS Code',
      icon: 'vscode',
      detected: detected,
      configured: false, // per-project, can't reliably detect
      configPath: '${_vscodeConfigDir}/settings.json',
    );
  }

  Future<bool> installVSCode() async {
    // VS Code uses per-project .vscode/mcp.json, not global
    // We'll add to global settings.json under mcp.servers
    return _installMcpConfig(
      'VS Code',
      '${_vscodeConfigDir}/settings.json',
      wrapInMcpServers: false,
      vscodeMode: true,
    );
  }

  // ─── Install All ───

  Future<void> installAll() async {
    for (final tool in currentTools) {
      if (tool.detected && !tool.configured) {
        switch (tool.name) {
          case 'Cursor':
            await installCursor();
          case 'Claude Desktop':
            await installClaudeDesktop();
          case 'Claude Code':
            await installClaudeCode();
          case 'VS Code':
            await installVSCode();
        }
      }
    }
    await detectAll();
  }

  // ─── Core config writer ───

  Future<bool> _installMcpConfig(
    String toolName,
    String configPath, {
    required bool wrapInMcpServers,
    bool vscodeMode = false,
  }) async {
    _updateTool(toolName, installing: true);
    _logService.addLine('hub', 'Installing OpenMob MCP config for $toolName...');

    try {
      final file = File(configPath);
      await file.parent.create(recursive: true);

      Map<String, dynamic> config = {};
      if (file.existsSync()) {
        try {
          config = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        } catch (_) {
          // Corrupt or empty file — start fresh
        }
      }

      // Build the OpenMob server entry
      final Map<String, dynamic> serverEntry;
      if (_mcpIsBinary) {
        serverEntry = {
          'command': _mcpCommand,
          'args': <String>[],
        };
      } else {
        serverEntry = {
          'command': 'node',
          'args': [_mcpCommand],
        };
        if (_mcpCwd.isNotEmpty) {
          serverEntry['cwd'] = _mcpCwd;
        }
      }

      if (vscodeMode) {
        // VS Code: settings.json → "mcp" → "servers" → "openmob"
        final mcp = (config['mcp'] as Map<String, dynamic>?) ?? {};
        final servers = (mcp['servers'] as Map<String, dynamic>?) ?? {};
        servers['openmob'] = {
          'type': 'stdio',
          ...serverEntry,
        };
        mcp['servers'] = servers;
        config['mcp'] = mcp;
      } else if (wrapInMcpServers) {
        // Cursor/Claude: "mcpServers" → "openmob"
        final servers = (config['mcpServers'] as Map<String, dynamic>?) ?? {};
        servers['openmob'] = serverEntry;
        config['mcpServers'] = servers;
      }

      // Write with pretty formatting
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(config),
      );

      _logService.addLine('hub', 'OpenMob configured for $toolName at $configPath');
      _updateTool(toolName, installing: false, configured: true);
      return true;
    } catch (e) {
      _logService.addLine('hub', 'Failed to configure $toolName: $e',
          level: LogLevel.error);
      _updateTool(toolName, installing: false);
      return false;
    }
  }

  // ─── Helpers ───

  bool _hasOpenMobConfig(String configPath) {
    try {
      final content = File(configPath).readAsStringSync();
      return content.contains('openmob');
    } catch (_) {
      return false;
    }
  }

  bool _commandExists(String cmd) {
    try {
      final result = Process.runSync(
        Platform.isWindows ? 'where' : 'which',
        [cmd],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  String get _homeDir =>
      Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';

  void _updateTool(String name, {bool? installing, bool? configured}) {
    final updated = currentTools.map((t) {
      if (t.name == name) {
        return t.copyWith(installing: installing, configured: configured);
      }
      return t;
    }).toList();
    _tools.add(updated);
  }

  void dispose() {
    _tools.close();
  }
}
