import 'dart:convert';
import 'dart:io';

import 'package:rxdart/rxdart.dart';

enum LogLevel { info, warning, error, debug }

class LogEntry {
  final DateTime timestamp;
  final String source;
  final String message;
  final LogLevel level;

  const LogEntry({
    required this.timestamp,
    required this.source,
    required this.message,
    this.level = LogLevel.info,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'source': source,
    'message': message,
    'level': level.name,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    timestamp: DateTime.parse(json['timestamp'] as String),
    source: json['source'] as String,
    message: json['message'] as String,
    level: LogLevel.values.firstWhere(
      (e) => e.name == json['level'],
      orElse: () => LogLevel.info,
    ),
  );
}

class LogService {
  static const int _maxEntries = 1000;

  final _logs = BehaviorSubject<List<LogEntry>>.seeded([]);

  ValueStream<List<LogEntry>> get logs$ => _logs.stream;

  List<LogEntry> get currentLogs => _logs.value;

  LogService() {
    _loadFromDisk();
  }

  void addLine(String source, String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      source: source,
      message: message,
      level: level,
    );
    final updated = [entry, ..._logs.value];
    if (updated.length > _maxEntries) {
      _logs.add(updated.sublist(0, _maxEntries));
    } else {
      _logs.add(updated);
    }
    _saveToDisk();
  }

  void clear() {
    _logs.add([]);
    _saveToDisk();
  }

  // ─── Persistence ───

  File get _file {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ?? '.';
    final dir = Directory('$home/.openmob/data');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/logs.json');
  }

  void _loadFromDisk() {
    try {
      final f = _file;
      if (f.existsSync()) {
        final data = jsonDecode(f.readAsStringSync()) as List<dynamic>;
        final entries = data
            .map((e) => LogEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        _logs.add(entries);
      }
    } catch (_) {
      // Corrupt file — start fresh
    }
  }

  void _saveToDisk() {
    try {
      // Only persist last 500 entries to keep file small
      final toSave = _logs.value.take(500).toList();
      _file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(
          toSave.map((e) => e.toJson()).toList(),
        ),
      );
    } catch (_) {
      // Disk write failed — non-critical
    }
  }

  void dispose() {
    _saveToDisk();
    _logs.close();
  }
}
