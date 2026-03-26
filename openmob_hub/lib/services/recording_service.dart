import 'dart:async';
import 'dart:io';

import 'package:rxdart/rxdart.dart';

import 'adb_service.dart';
import 'log_service.dart';

/// Active recording session
class Recording {
  final String id;
  final String deviceSerial;
  final String filePath;
  final String backend; // 'screenrecord' or 'scrcpy'
  final String format;
  final DateTime startedAt;
  DateTime? stoppedAt;
  int? durationMs;
  int? fileSizeBytes;
  bool isActive;
  final List<RecordingEvent> events;
  Process? _process;

  Recording({
    required this.id,
    required this.deviceSerial,
    required this.filePath,
    required this.backend,
    required this.format,
    required this.startedAt,
    this.isActive = true,
    List<RecordingEvent>? events,
  }) : events = events ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'device_id': deviceSerial,
        'file_path': filePath,
        'backend': backend,
        'format': format,
        'started_at': startedAt.toIso8601String(),
        'stopped_at': stoppedAt?.toIso8601String(),
        'duration_ms': durationMs,
        'file_size_bytes': fileSizeBytes,
        'is_active': isActive,
        'event_count': events.length,
      };
}

/// A timestamped event during recording (for SRT subtitle generation)
class RecordingEvent {
  final DateTime timestamp;
  final String action;
  final String description;

  RecordingEvent({
    required this.timestamp,
    required this.action,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'action': action,
        'description': description,
      };
}

class RecordingService {
  final AdbService _adb;
  final LogService? _logService;

  RecordingService(this._adb, {LogService? logService})
      : _logService = logService;

  final _recordings = BehaviorSubject<Map<String, Recording>>.seeded({});
  ValueStream<Map<String, Recording>> get recordings$ => _recordings.stream;

  /// Get recordings dir — ~/.openmob/recordings/
  String get _recordingsDir {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$home${Platform.pathSeparator}.openmob${Platform.pathSeparator}recordings';
  }

  /// Check if scrcpy is available
  Future<String?> _findScrcpy() async {
    // Check ~/.openmob/tools/scrcpy/
    final toolsDir =
        '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.'}'
        '${Platform.pathSeparator}.openmob${Platform.pathSeparator}tools${Platform.pathSeparator}scrcpy';
    final ext = Platform.isWindows ? '.exe' : '';
    final localBin = '$toolsDir${Platform.pathSeparator}scrcpy$ext';
    if (await File(localBin).exists()) return localBin;

    // Check PATH
    try {
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        ['scrcpy'],
      );
      if (result.exitCode == 0) {
        return (result.stdout as String).trim().split('\n').first.trim();
      }
    } catch (_) {}
    return null;
  }

  /// Start recording a device screen
  Future<Recording> startRecording(
    String serial, {
    String format = 'mkv',
    int maxDurationSeconds = 180,
    bool includeAudio = false,
    String videoBitrate = '4M',
  }) async {
    // Check for existing active recording on this device
    final existing = _recordings.value.values
        .where((r) => r.deviceSerial == serial && r.isActive)
        .toList();
    if (existing.isNotEmpty) {
      throw StateError(
          'Device $serial already has an active recording: ${existing.first.id}');
    }

    await Directory(_recordingsDir).create(recursive: true);

    final id =
        'rec_${DateTime.now().millisecondsSinceEpoch}_${serial.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}';
    final scrcpyPath = await _findScrcpy();
    final useScrcpy = scrcpyPath != null &&
        (includeAudio || maxDurationSeconds > 180 || format == 'mkv');

    final String filePath;
    final String backend;
    Process process;

    if (useScrcpy) {
      // --- scrcpy backend ---
      backend = 'scrcpy';
      filePath =
          '$_recordingsDir${Platform.pathSeparator}$id.$format';

      final args = <String>[
        '--no-playback',
        '--no-window',
        '--no-control',
        '--record=$filePath',
        '--record-format=$format',
        '--video-bit-rate=$videoBitrate',
        '-s', serial,
      ];

      if (!includeAudio) args.add('--no-audio');
      if (maxDurationSeconds > 0) {
        args.add('--time-limit=$maxDurationSeconds');
      }

      process = await Process.start(scrcpyPath, args);
      _logService?.addLine(
          'recording', 'Started scrcpy recording: $id ($format)');
    } else {
      // --- adb screenrecord backend ---
      backend = 'screenrecord';
      final devicePath = '/sdcard/openmob_$id.mp4';
      filePath =
          '$_recordingsDir${Platform.pathSeparator}$id.mp4';

      final adbPath = await _adb.adbPath;
      final effectiveDuration =
          maxDurationSeconds > 180 ? 180 : maxDurationSeconds;

      process = await Process.start(adbPath, [
        '-s', serial,
        'shell', 'screenrecord',
        '--time-limit', '$effectiveDuration',
        '--bit-rate', _parseBitrate(videoBitrate).toString(),
        devicePath,
      ]);

      _logService?.addLine('recording',
          'Started screenrecord: $id (max ${effectiveDuration}s)');
    }

    final recording = Recording(
      id: id,
      deviceSerial: serial,
      filePath: filePath,
      backend: backend,
      format: useScrcpy ? format : 'mp4',
      startedAt: DateTime.now(),
    );
    recording._process = process;

    // Monitor process exit
    process.exitCode.then((code) {
      _onRecordingEnded(recording);
    });

    final map = Map<String, Recording>.from(_recordings.value);
    map[id] = recording;
    _recordings.add(map);

    return recording;
  }

  /// Stop an active recording
  Future<Recording> stopRecording(String serial, {String? recordingId}) async {
    Recording? recording;

    if (recordingId != null) {
      recording = _recordings.value[recordingId];
    } else {
      // Find active recording for device
      recording = _recordings.value.values
          .where((r) => r.deviceSerial == serial && r.isActive)
          .firstOrNull;
    }

    if (recording == null) {
      throw StateError('No active recording found for device $serial');
    }

    if (!recording.isActive) {
      return recording;
    }

    final process = recording._process;
    if (process != null) {
      if (recording.backend == 'scrcpy') {
        // Send SIGINT for clean MKV finalization
        if (Platform.isWindows) {
          // Windows: kill the process (MKV survives unclean kill)
          process.kill(ProcessSignal.sigterm);
        } else {
          process.kill(ProcessSignal.sigint);
        }
      } else {
        // adb screenrecord: kill the device-side process
        final adbPath = await _adb.adbPath;
        await Process.run(adbPath, [
          '-s', recording.deviceSerial,
          'shell', 'pkill', '-SIGINT', 'screenrecord',
        ]);
      }

      // Wait for process to finish (timeout 10s)
      try {
        await process.exitCode.timeout(const Duration(seconds: 10));
      } catch (_) {
        process.kill(ProcessSignal.sigkill);
      }
    }

    // For screenrecord: pull file from device
    if (recording.backend == 'screenrecord') {
      final adbPath = await _adb.adbPath;
      final devicePath =
          '/sdcard/openmob_${recording.id}.mp4';
      await Process.run(adbPath, [
        '-s', recording.deviceSerial,
        'pull', devicePath, recording.filePath,
      ]);
      // Cleanup device file
      await Process.run(adbPath, [
        '-s', recording.deviceSerial,
        'shell', 'rm', '-f', devicePath,
      ]);
    }

    await _onRecordingEnded(recording);

    // Generate SRT subtitle file if there are events
    if (recording.events.isNotEmpty) {
      await _generateSrt(recording);
    }

    return recording;
  }

  /// Add a timestamped event to the active recording
  void addEvent(String serial, String action, String description) {
    final recording = _recordings.value.values
        .where((r) => r.deviceSerial == serial && r.isActive)
        .firstOrNull;
    if (recording == null) return;

    recording.events.add(RecordingEvent(
      timestamp: DateTime.now(),
      action: action,
      description: description,
    ));
  }

  /// Get a specific recording
  Recording? getRecording(String recordingId) => _recordings.value[recordingId];

  /// List all recordings, optionally filtered by device
  List<Recording> listRecordings({String? deviceSerial}) {
    final all = _recordings.value.values.toList();
    if (deviceSerial != null) {
      return all.where((r) => r.deviceSerial == deviceSerial).toList();
    }
    return all;
  }

  /// Get active recording for a device
  Recording? getActiveRecording(String serial) {
    return _recordings.value.values
        .where((r) => r.deviceSerial == serial && r.isActive)
        .firstOrNull;
  }

  // ─── Private helpers ───

  Future<void> _onRecordingEnded(Recording recording) async {
    recording.isActive = false;
    recording.stoppedAt = DateTime.now();
    recording.durationMs = recording.stoppedAt!
        .difference(recording.startedAt)
        .inMilliseconds;

    try {
      final file = File(recording.filePath);
      if (await file.exists()) {
        recording.fileSizeBytes = await file.length();
      }
    } catch (_) {}

    _logService?.addLine('recording',
        'Recording ${recording.id} stopped (${(recording.durationMs! / 1000).toStringAsFixed(1)}s, ${_formatSize(recording.fileSizeBytes ?? 0)})');

    // Emit update
    final map = Map<String, Recording>.from(_recordings.value);
    map[recording.id] = recording;
    _recordings.add(map);
  }

  /// Generate SRT subtitle file with action timestamps
  Future<void> _generateSrt(Recording recording) async {
    final srtPath =
        recording.filePath.replaceAll(RegExp(r'\.(mkv|mp4)$'), '.srt');
    final buffer = StringBuffer();

    for (var i = 0; i < recording.events.length; i++) {
      final event = recording.events[i];
      final offset = event.timestamp.difference(recording.startedAt);
      final start = _formatSrtTime(offset);
      final end = _formatSrtTime(offset + const Duration(seconds: 2));

      buffer.writeln('${i + 1}');
      buffer.writeln('$start --> $end');
      buffer.writeln('${event.description}');
      buffer.writeln();
    }

    await File(srtPath).writeAsString(buffer.toString());
    _logService?.addLine(
        'recording', 'Generated SRT subtitles: $srtPath');
  }

  String _formatSrtTime(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }

  int _parseBitrate(String bitrate) {
    final lower = bitrate.toLowerCase().trim();
    if (lower.endsWith('m')) {
      return (double.parse(lower.replaceAll('m', '')) * 1000000).toInt();
    }
    if (lower.endsWith('k')) {
      return (double.parse(lower.replaceAll('k', '')) * 1000).toInt();
    }
    return int.tryParse(lower) ?? 4000000;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  void dispose() {
    // Stop all active recordings
    for (final r in _recordings.value.values) {
      if (r.isActive) r._process?.kill();
    }
    _recordings.close();
  }
}
