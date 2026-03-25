import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

import 'log_service.dart';

/// Version is set in pubspec.yaml — update there before creating a release.
/// The workflow reads it from the tag the user provides manually.
const _currentVersion = '0.0.6';
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

  /// Check GitHub for latest release
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
          error: 'GitHub API error: ${response.statusCode}',
        ));
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final latestVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final releaseNotes = data['body'] as String? ?? '';
      final assets = data['assets'] as List<dynamic>? ?? [];

      // Compare versions
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
        error: 'Could not check for updates: $e',
      ));
      _log('Update check failed: $e', error: true);
    }
  }

  /// Download and install the latest release
  Future<void> downloadAndInstall() async {
    final info = _status.value;
    if (info.downloadUrl == null) {
      _status.add(UpdateInfo(
        status: UpdateStatus.error,
        error: 'No download URL available',
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
      final downloadDir = '$home${sep}.openmob${sep}updates';
      await Directory(downloadDir).create(recursive: true);

      final fileName = info.downloadUrl!.split('/').last;
      final filePath = '$downloadDir$sep$fileName';

      // Download with progress
      final request = http.Request('GET', Uri.parse(info.downloadUrl!));
      final streamedResponse = await request.send();
      final totalBytes = streamedResponse.contentLength ?? 0;
      var receivedBytes = 0;

      final file = File(filePath);
      final sink = file.openWrite();

      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = receivedBytes / totalBytes;
          _status.add(UpdateInfo(
            status: UpdateStatus.downloading,
            latestVersion: info.latestVersion,
            progress: progress,
          ));
        }
      }
      await sink.close();

      _status.add(UpdateInfo(
        status: UpdateStatus.installing,
        latestVersion: info.latestVersion,
        progress: 1.0,
      ));
      _log('Downloaded to $filePath');

      // Extract the archive
      if (filePath.endsWith('.tar.gz')) {
        await Process.run('tar', ['-xzf', filePath, '-C', downloadDir]);
      } else if (filePath.endsWith('.zip')) {
        if (Platform.isWindows) {
          await Process.run('powershell', [
            '-Command',
            'Expand-Archive -Path "$filePath" -DestinationPath "$downloadDir" -Force',
          ]);
        } else {
          await Process.run('unzip', ['-o', filePath, '-d', downloadDir]);
        }
      }

      _log('Update downloaded and extracted to $downloadDir');
      _log('Restart the app to apply the update');

      _status.add(UpdateInfo(
        status: UpdateStatus.available,
        latestVersion: info.latestVersion,
        releaseNotes: 'Update downloaded. Restart the app to apply.',
      ));
    } catch (e) {
      _status.add(UpdateInfo(
        status: UpdateStatus.error,
        error: 'Download failed: $e',
      ));
      _log('Update download failed: $e', error: true);
    }
  }

  /// Get the expected asset filename for this platform
  String _getAssetName() {
    if (Platform.isWindows) return 'windows-x64';
    if (Platform.isMacOS) return 'macos';
    return 'linux-x64';
  }

  /// Compare version strings (semver)
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

  void _log(String message, {bool error = false}) {
    _logService.addLine('hub', message, level: error ? LogLevel.error : LogLevel.info);
  }

  void dispose() {
    _status.close();
  }
}
