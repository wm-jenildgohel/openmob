import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:rxdart/rxdart.dart';

import 'adb_service.dart';
import 'log_service.dart';

/// Manages scrcpy-server streaming for live device mirroring.
/// Pushes the server JAR to device, forwards TCP port, starts server
/// with raw H.264 stream, and exposes a TCP URL for media_kit to play.
class ScrcpyStreamService {
  final AdbService _adb;
  final LogService? _logService;

  ScrcpyStreamService(this._adb, {LogService? logService})
      : _logService = logService;

  // Active streams per device serial
  final _streams = BehaviorSubject<Map<String, _StreamSession>>.seeded({});
  ValueStream<Map<String, _StreamSession>> get streams$ => _streams.stream;

  /// Get the scrcpy-server binary path (bundled or downloaded)
  Future<String?> _findServerBinary() async {
    final sep = Platform.pathSeparator;

    // Check bundled (next to exe)
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    for (final name in ['scrcpy-server', 'scrcpy-server.jar']) {
      final candidate = '$exeDir$sep$name';
      if (await File(candidate).exists()) return candidate;
    }

    // Check ~/.openmob/tools/scrcpy/
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    final toolsDir = '$home$sep.openmob${sep}tools${sep}scrcpy';
    for (final name in ['scrcpy-server', 'scrcpy-server.jar']) {
      final candidate = '$toolsDir$sep$name';
      if (await File(candidate).exists()) return candidate;
    }

    // Check standard system locations
    final systemPaths = [
      '/usr/local/share/scrcpy/scrcpy-server',
      '/usr/share/scrcpy/scrcpy-server',
      '/opt/scrcpy/scrcpy-server',
      if (Platform.isWindows) ...([
        'C:\\Program Files\\scrcpy\\scrcpy-server',
        'C:\\scrcpy\\scrcpy-server',
      ]),
    ];
    for (final path in systemPaths) {
      if (await File(path).exists()) return path;
    }

    // Check if scrcpy is installed and find server relative to its binary
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['scrcpy'],
      );
      if (result.exitCode == 0) {
        final scrcpyPath =
            (result.stdout as String).trim().split('\n').first.trim();
        final scrcpyDir = File(scrcpyPath).parent.path;

        // Check next to the binary
        for (final name in ['scrcpy-server', 'scrcpy-server.jar']) {
          final candidate = '$scrcpyDir$sep$name';
          if (await File(candidate).exists()) return candidate;
        }

        // Check ../share/scrcpy/ (standard Linux FHS layout: bin/ → share/scrcpy/)
        final shareDir = '${File(scrcpyPath).parent.parent.path}${sep}share${sep}scrcpy';
        final shareServer = '$shareDir${sep}scrcpy-server';
        if (await File(shareServer).exists()) return shareServer;
      }
    } catch (_) {}

    return null;
  }

  /// Start streaming from a device. Returns the TCP URL for media_kit.
  Future<String?> startStream(
    String serial, {
    int maxSize = 1080,
    int videoBitrate = 4000000,
  }) async {
    // Already streaming?
    final current = _streams.value;
    if (current.containsKey(serial) && current[serial]!.isActive) {
      return current[serial]!.tcpUrl;
    }

    final serverPath = await _findServerBinary();
    if (serverPath == null) {
      _logService?.addLine(
          'mirror', 'scrcpy-server not found — install scrcpy first',
          level: LogLevel.error);
      return null;
    }

    final adbPath = await _adb.adbPath;

    // Pick a random available port (27183-27283 range)
    final port = 27183 + Random().nextInt(100);

    try {
      // 1. Push server to device
      _logService?.addLine('mirror', 'Pushing scrcpy-server to $serial...');
      await Process.run(
          adbPath, ['-s', serial, 'push', serverPath, '/data/local/tmp/scrcpy-server.jar']);

      // 2. Forward TCP port
      await Process.run(
          adbPath, ['-s', serial, 'forward', 'tcp:$port', 'localabstract:scrcpy']);

      // 3. Start scrcpy-server
      _logService?.addLine('mirror', 'Starting scrcpy-server on $serial (port $port)...');
      final serverProcess = await Process.start(adbPath, [
        '-s', serial,
        'shell',
        'CLASSPATH=/data/local/tmp/scrcpy-server.jar',
        'app_process', '/', 'com.genymobile.scrcpy.Server',
        '3.1',  // server version — must match the binary
        'tunnel_forward=true',
        'audio=false',
        'control=false',
        'cleanup=false',
        'raw_stream=true',
        'max_size=$maxSize',
        'video_codec=h264',
        'video_bit_rate=$videoBitrate',
      ]);

      // Give server time to start
      await Future.delayed(const Duration(milliseconds: 500));

      final tcpUrl = 'tcp://127.0.0.1:$port';

      final session = _StreamSession(
        serial: serial,
        port: port,
        tcpUrl: tcpUrl,
        serverProcess: serverProcess,
        isActive: true,
      );

      // Monitor exit
      serverProcess.exitCode.then((_) {
        _logService?.addLine('mirror', 'scrcpy-server stopped for $serial');
        final updated = Map<String, _StreamSession>.from(_streams.value);
        updated.remove(serial);
        _streams.add(updated);
      });

      // Store stderr for debugging
      serverProcess.stderr
          .transform(const SystemEncoding().decoder)
          .listen((line) {
        if (line.trim().isNotEmpty) {
          _logService?.addLine('mirror', '[scrcpy] $line');
        }
      });

      final updated = Map<String, _StreamSession>.from(_streams.value);
      updated[serial] = session;
      _streams.add(updated);

      _logService?.addLine('mirror', 'Live stream ready: $tcpUrl');
      return tcpUrl;
    } catch (e) {
      _logService?.addLine('mirror', 'Failed to start stream: $e',
          level: LogLevel.error);
      return null;
    }
  }

  /// Stop streaming from a device
  Future<void> stopStream(String serial) async {
    final current = _streams.value;
    final session = current[serial];
    if (session == null) return;

    session.serverProcess.kill();

    // Remove port forward
    final adbPath = await _adb.adbPath;
    await Process.run(
        adbPath, ['-s', serial, 'forward', '--remove', 'tcp:${session.port}']);

    final updated = Map<String, _StreamSession>.from(_streams.value);
    updated.remove(serial);
    _streams.add(updated);

    _logService?.addLine('mirror', 'Stream stopped for $serial');
  }

  /// Check if a device is currently streaming
  bool isStreaming(String serial) {
    final session = _streams.value[serial];
    return session != null && session.isActive;
  }

  /// Get TCP URL for a streaming device
  String? getStreamUrl(String serial) => _streams.value[serial]?.tcpUrl;

  void dispose() {
    for (final session in _streams.value.values) {
      session.serverProcess.kill();
    }
    _streams.close();
  }
}

class _StreamSession {
  final String serial;
  final int port;
  final String tcpUrl;
  final Process serverProcess;
  bool isActive;

  _StreamSession({
    required this.serial,
    required this.port,
    required this.tcpUrl,
    required this.serverProcess,
    this.isActive = true,
  });
}
