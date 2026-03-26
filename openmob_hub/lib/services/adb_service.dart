import 'dart:io';
import 'dart:convert';

class AdbService {
  String? _adbPath;

  Future<String> get adbPath async {
    if (_adbPath != null) return _adbPath!;
    // Try ANDROID_HOME first
    final androidHome = Platform.environment['ANDROID_HOME'] ??
        Platform.environment['ANDROID_SDK_ROOT'];
    if (androidHome != null) {
      final sep = Platform.pathSeparator;
      final ext = Platform.isWindows ? '.exe' : '';
      final candidate = '$androidHome${sep}platform-tools${sep}adb$ext';
      if (await File(candidate).exists()) {
        _adbPath = candidate;
        return _adbPath!;
      }
    }
    // Fallback to PATH lookup
    try {
      final result = Process.runSync(
        Platform.isWindows ? 'where' : 'which',
        ['adb'],
      );
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim().split('\n').first.trim();
        if (path.isNotEmpty) {
          _adbPath = path;
          return _adbPath!;
        }
      }
    } catch (_) {}
    throw Exception('ADB not found. Set ANDROID_HOME or add adb to PATH.');
  }

  Future<ProcessResult> run(
    String serial,
    List<String> args, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final adb = await adbPath;
    final fullArgs = ['-s', serial, ...args];
    return Process.run(adb, fullArgs, stdoutEncoding: utf8);
  }

  Future<List<int>> runBinary(String serial, List<String> args) async {
    final adb = await adbPath;
    final fullArgs = ['-s', serial, ...args];
    final process = await Process.start(adb, fullArgs);
    final bytes = await process.stdout.fold<List<int>>(
      [],
      (prev, chunk) => prev..addAll(chunk),
    );
    await process.exitCode;
    return bytes;
  }

  Future<ProcessResult> runGlobal(List<String> args) async {
    final adb = await adbPath;
    return Process.run(adb, args, stdoutEncoding: utf8);
  }

  /// Parse 'adb devices' raw output into serial+status pairs
  Future<List<({String serial, String status, bool isEmulator, bool isWifi})>>
      listRawDevices() async {
    final result = await runGlobal(['devices']);
    // Strip \r to handle Windows \r\n line endings from ADB
    final lines = (result.stdout as String).replaceAll('\r', '').split('\n');
    return lines
        .skip(1)
        .where((l) => l.trim().isNotEmpty)
        .map((line) {
          final parts = line.trim().split(RegExp(r'\s+'));
          return (
            serial: parts[0].trim(),
            status: parts.length > 1 ? parts[1].trim() : 'unknown',
            isEmulator: parts[0].startsWith('emulator-'),
            isWifi: parts[0].contains(':'),
          );
        })
        .toList();
  }
}
