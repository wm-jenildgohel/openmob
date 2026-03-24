import 'dart:convert';
import 'dart:typed_data';
import 'adb_service.dart';
import 'device_manager.dart';
import 'simctl_service.dart';

class ScreenshotService {
  final AdbService _adb;
  final SimctlService? _simctl;
  final DeviceManager _dm;

  ScreenshotService(this._adb, {SimctlService? simctl, required DeviceManager dm})
      : _simctl = simctl,
        _dm = dm;

  /// Capture a PNG screenshot from the device.
  /// Routes to simctl for iOS or ADB for Android.
  /// Returns a record with base64-encoded PNG, width, and height.
  Future<({String base64, int width, int height})> captureScreenshot(
    String serial,
  ) async {
    final device = _dm.getDevice(serial);

    // iOS path: use simctl
    if (device?.platform == 'ios' && _simctl != null) {
      final rawBytes = await _simctl.captureScreenshot(serial);
      final bytes = Uint8List.fromList(rawBytes);
      final encoded = base64Encode(bytes);
      final dims = _parsePngDimensions(bytes);
      return (base64: encoded, width: dims.width, height: dims.height);
    }

    // Android path: use ADB (existing)
    final bytes = await _adb.runBinary(
      serial,
      ['exec-out', 'screencap', '-p'],
    );

    final encoded = base64Encode(bytes);
    final dims = _parsePngDimensions(bytes);

    return (base64: encoded, width: dims.width, height: dims.height);
  }

  /// Parse width and height from PNG IHDR chunk.
  /// PNG header: 8 bytes signature, then IHDR chunk with width at offset 16
  /// and height at offset 20 (both 4 bytes big-endian).
  ({int width, int height}) _parsePngDimensions(List<int> bytes) {
    if (bytes.length < 24) return (width: 0, height: 0);

    // Verify PNG signature: 137 80 78 71 13 10 26 10
    if (bytes[0] != 0x89 ||
        bytes[1] != 0x50 ||
        bytes[2] != 0x4E ||
        bytes[3] != 0x47) {
      return (width: 0, height: 0);
    }

    try {
      final data = Uint8List.fromList(bytes);
      final byteData = ByteData.sublistView(data);
      final width = byteData.getUint32(16, Endian.big);
      final height = byteData.getUint32(20, Endian.big);
      return (width: width, height: height);
    } catch (_) {
      return (width: 0, height: 0);
    }
  }
}
