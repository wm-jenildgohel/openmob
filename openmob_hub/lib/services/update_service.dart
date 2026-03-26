import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

import 'log_service.dart';

const _currentVersion = '0.0.7';
const _repoOwner = 'wm-jenildgohel';
const _repoName = 'openmob';
const _apiBase = 'https://api.github.com/repos/$_repoOwner/$_repoName';

enum UpdateStatus { idle, checking, available, downloading, installing, upToDate, error }

class UpdateInfo {
  final UpdateStatus status;
  final String currentVersion;
  final String? latestVersion;
  final String? downloadUrl;
  final String? releaseNotes;
  final double progress;
  final String? error;

  const UpdateInfo({
    this.status = UpdateStatus.idle,
    this.currentVersion = _currentVersion,
    this.latestVersion,
    this.downloadUrl,
    this.releaseNotes,
    this.progress = 0.0,
    this.error,
  });
}

class UpdateService {
  final LogService _logService;

  UpdateService(this._logService);

  final _status = BehaviorSubject<UpdateInfo>.seeded(const UpdateInfo());
  ValueStream<UpdateInfo> get status$ => _status.stream;

  String get currentVersion => _currentVersion;

  Future<void> checkForUpdate() async {
    _status.add(const UpdateInfo(status: UpdateStatus.checking));
    _log('Checking for updates...');

    try {
      final response = await http
          .get(Uri.parse('$_apiBase/releases/latest'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        _status.add(const UpdateInfo(status: UpdateStatus.upToDate));
        _log('No releases found yet');
        return;
      }

      if (response.statusCode != 200) {
        _status.add(UpdateInfo(
          status: UpdateStatus.error,
          error: 'Could not check — try again later',
        ));
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final releaseNotes = data['body'] as String? ?? '';
      final assets = data['assets'] as List<dynamic>? ?? [];

      if (_isNewerVersion(latestVersion, _currentVersion)) {
        final assetName = _getAssetName();
        final asset = assets.firstWhere(
          (a) => (a['name'] as String).contains(assetName),
          orElse: () => null,
        );

        _status.add(UpdateInfo(
          status: UpdateStatus.available,
          latestVersion: latestVersion,
          downloadUrl: asset != null ? asset['browser_download_url'] as String : null,
          releaseNotes: releaseNotes,
        ));
        _log('Update available: v$latestVersion (current: v$_currentVersion)');
      } else {
        _status.add(const UpdateInfo(status: UpdateStatus.upToDate));
        _log('Up to date (v$_currentVersion)');
      }
    } catch (e) {
      _status.add(UpdateInfo(
        status: UpdateStatus.error,
        error: 'Could not check for updates',
      ));
      _log('Update check failed: $e', error: true);
    }
  }

  /// Download, extract, replace current app files, and relaunch
  Future<void> downloadAndInstall() async {
    final info = _status.value;
    if (info.downloadUrl == null) {
      _status.add(const UpdateInfo(
        status: UpdateStatus.error,
        error: 'No download link available',
      ));
      return;
    }

    _status.add(UpdateInfo(
      status: UpdateStatus.downloading,
      latestVersion: info.latestVersion,
      progress: 0.0,
    ));
    _log('Downloading v${info.latestVersion}...');

    try {
      final sep = Platform.pathSeparator;
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ?? '.';
      final updateDir = '$home${sep}.openmob${sep}updates';
      await Directory(updateDir).create(recursive: true);

      final fileName = info.downloadUrl!.split('/').last;
      final archivePath = '$updateDir$sep$fileName';

      // Step 1: Download with progress
      final request = http.Request('GET', Uri.parse(info.downloadUrl!));
      final streamedResponse = await request.send();
      final totalBytes = streamedResponse.contentLength ?? 0;
      var receivedBytes = 0;

      final archiveFile = File(archivePath);
      final sink = archiveFile.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _status.add(UpdateInfo(
            status: UpdateStatus.downloading,
            latestVersion: info.latestVersion,
            progress: receivedBytes / totalBytes * 0.5, // Download = 0-50%
          ));
        }
      }
      await sink.close();
      _log('Downloaded ${(receivedBytes / 1024 / 1024).toStringAsFixed(1)} MB');

      // Step 2: Extract
      _status.add(UpdateInfo(
        status: UpdateStatus.installing,
        latestVersion: info.latestVersion,
        progress: 0.55,
      ));
      _log('Extracting update...');

      final extractDir = '$updateDir${sep}extracted';
      if (Directory(extractDir).existsSync()) {
        Directory(extractDir).deleteSync(recursive: true);
      }
      await Directory(extractDir).create(recursive: true);

      if (archivePath.endsWith('.zip')) {
        if (Platform.isWindows) {
          await Process.run('powershell', [
            '-Command',
            'Expand-Archive -Path "$archivePath" -DestinationPath "$extractDir" -Force',
          ]);
        } else {
          await Process.run('unzip', ['-o', archivePath, '-d', extractDir]);
        }
      } else if (archivePath.endsWith('.tar.gz')) {
        await Process.run('tar', ['-xzf', archivePath, '-C', extractDir]);
      }

      // Step 3: Find the extracted folder (e.g., openmob-windows-x64/)
      final extractedContents = Directory(extractDir).listSync();
      Directory? sourceDir;
      for (final entry in extractedContents) {
        if (entry is Directory) {
          sourceDir = entry;
          break;
        }
      }

      if (sourceDir == null) {
        throw Exception('Extracted archive is empty');
      }

      _status.add(UpdateInfo(
        status: UpdateStatus.installing,
        latestVersion: info.latestVersion,
        progress: 0.7,
      ));

      // Step 4: Replace current app files
      final appDir = File(Platform.resolvedExecutable).parent;
      _log('Replacing app files in ${appDir.path}...');

      if (Platform.isWindows) {
        // On Windows, the running .exe is locked. Use a batch script that:
        // 1. Waits for the app to exit
        // 2. Copies new files over old ones
        // 3. Relaunches the app
        final batchScript = '''
@echo off
echo Updating OpenMob...
timeout /t 2 /nobreak >nul
xcopy /s /y /q "${sourceDir.path}\\*" "${appDir.path}\\"
start "" "${Platform.resolvedExecutable}"
del "%~f0"
''';
        final batchPath = '$updateDir${sep}update.bat';
        await File(batchPath).writeAsString(batchScript);

        _status.add(UpdateInfo(
          status: UpdateStatus.installing,
          latestVersion: info.latestVersion,
          progress: 0.9,
        ));

        _log('Update ready — restarting...');

        // Launch the update script and exit the app
        await Process.start('cmd', ['/c', batchPath],
            mode: ProcessStartMode.detached);

        // Clean up archive
        await archiveFile.delete().catchError((_) => archiveFile);

        // Exit the app — the batch script will copy new files and relaunch
        exit(0);
      } else {
        // On Linux/macOS, we can replace files while running (only the binary is locked)
        // Copy all new files over existing ones
        await _copyDirectory(sourceDir, appDir);

        _status.add(UpdateInfo(
          status: UpdateStatus.installing,
          latestVersion: info.latestVersion,
          progress: 0.9,
        ));

        // Clean up
        await archiveFile.delete().catchError((_) => archiveFile);
        await Directory(extractDir).delete(recursive: true).catchError((_) => Directory(extractDir));

        _log('Update installed — restarting...');

        // Relaunch the app
        await Process.start(
          Platform.resolvedExecutable,
          [],
          mode: ProcessStartMode.detached,
        );

        exit(0);
      }
    } catch (e) {
      _status.add(UpdateInfo(
        status: UpdateStatus.error,
        error: 'Update failed: ${_friendlyError(e.toString())}',
        latestVersion: info.latestVersion,
      ));
      _log('Update failed: $e', error: true);
    }
  }

  /// Recursively copy directory contents
  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final targetPath = '${target.path}${Platform.pathSeparator}${entity.uri.pathSegments.last}';
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        try {
          await entity.copy(targetPath);
        } catch (e) {
          // File might be locked (running binary) — skip it, it's the current exe
          _log('Skipped locked file: ${entity.path}');
        }
      }
    }
  }

  String _getAssetName() {
    if (Platform.isWindows) return 'windows-x64';
    if (Platform.isMacOS) return 'macos';
    return 'linux-x64';
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();
      for (var i = 0; i < 3; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  String _friendlyError(String error) {
    if (error.contains('SocketException')) return 'No internet connection';
    if (error.contains('HandshakeException')) return 'Network security error';
    if (error.contains('Permission')) return 'Permission denied — run as administrator';
    if (error.contains('space')) return 'Not enough disk space';
    return 'Something went wrong — try again';
  }

  void _log(String message, {bool error = false}) {
    _logService.addLine('hub', message, level: error ? LogLevel.error : LogLevel.info);
  }

  void dispose() {
    _status.close();
  }
}
