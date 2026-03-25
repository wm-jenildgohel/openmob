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
}

class LogService {
  static const int _maxEntries = 1000;

  final _logs = BehaviorSubject<List<LogEntry>>.seeded([]);

  ValueStream<List<LogEntry>> get logs$ => _logs.stream;

  List<LogEntry> get currentLogs => _logs.value;

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
  }

  void clear() {
    _logs.add([]);
  }

  void dispose() {
    _logs.close();
  }
}
