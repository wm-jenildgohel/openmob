import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../models/device.dart';
import '../core/constants.dart';
import 'adb_service.dart';
import 'simctl_service.dart';
import 'idb_service.dart';

class DeviceManager {
  final AdbService _adb;
  final SimctlService? _simctl;
  final IdbService? _idb;

  DeviceManager(this._adb, {SimctlService? simctl, IdbService? idb})
      : _simctl = simctl,
        _idb = idb;

  final _devices = BehaviorSubject<List<Device>>.seeded([]);

  // Track which devices have bridge enabled (survives refresh cycles)
  final Set<String> _bridgedDeviceIds = {};

  // Cache enriched device data — only re-enrich when new serial appears
  final Map<String, Device> _enrichmentCache = {};

  // Prevent concurrent refreshDevices() calls
  bool _refreshing = false;

  ValueStream<List<Device>> get devices$ => _devices.stream;

  List<Device> get currentDevices => _devices.value;

  SimctlService? get simctl => _simctl;
  IdbService? get idb => _idb;

  Future<void> refreshDevices() async {
    // Guard against concurrent refresh calls
    if (_refreshing) return;
    _refreshing = true;

    try {
      final rawDevices = await _adb.listRawDevices();

      // Separate new vs cached devices
      final needsEnrichment = <({String serial, String status, bool isEmulator, bool isWifi})>[];
      final fromCache = <Device>[];

      for (final raw in rawDevices) {
        if (raw.status == 'device') {
          if (_enrichmentCache.containsKey(raw.serial)) {
            fromCache.add(_enrichmentCache[raw.serial]!);
          } else {
            needsEnrichment.add(raw);
          }
        } else {
          // Non-connected devices don't need enrichment
          fromCache.add(Device.fromAdb(serial: raw.serial, status: raw.status));
        }
      }

      // Enrich NEW devices in parallel (not sequentially)
      final newlyEnriched = await Future.wait(
        needsEnrichment.map((raw) async {
          try {
            final device = await _enrichDevice(raw.serial);
            _enrichmentCache[raw.serial] = device;
            return device;
          } catch (_) {
            final basic = Device.fromAdb(serial: raw.serial, status: raw.status);
            _enrichmentCache[raw.serial] = basic;
            return basic;
          }
        }),
      );

      final enriched = [...fromCache, ...newlyEnriched];

      // Remove stale cache entries (device disconnected)
      final currentSerials = rawDevices.map((r) => r.serial).toSet();
      _enrichmentCache.removeWhere((serial, _) => !currentSerials.contains(serial));

      // Merge iOS simulators if simctl is available
      if (_simctl != null) {
        try {
          final simulators = await _simctl.listSimulators()
              .timeout(const Duration(seconds: 5));
          enriched.addAll(simulators);
        } catch (_) {
          // simctl timeout or error — skip iOS devices this cycle
        }
      }

      // Preserve bridge state across refresh cycles
      final merged = enriched.map((d) {
        if (_bridgedDeviceIds.contains(d.id)) {
          return d.copyWith(status: 'bridged', bridgeActive: true);
        }
        return d;
      }).toList();

      _devices.add(merged);
    } finally {
      _refreshing = false;
    }
  }

  /// Force re-enrichment for a specific device (e.g., after state change)
  void invalidateCache(String serial) {
    _enrichmentCache.remove(serial);
  }

  Future<Device> _enrichDevice(String serial) async {
    // All 6 ADB calls run in parallel
    final results = await Future.wait([
      _adb.run(serial, ['shell', 'getprop', 'ro.product.model']),
      _adb.run(serial, ['shell', 'getprop', 'ro.product.manufacturer']),
      _adb.run(serial, ['shell', 'getprop', 'ro.build.version.release']),
      _adb.run(serial, ['shell', 'getprop', 'ro.build.version.sdk']),
      _adb.run(serial, ['shell', 'wm', 'size']),
      _adb.run(serial, ['shell', 'dumpsys', 'battery']),
    ]);

    final model = (results[0].stdout as String).trim();
    final manufacturer = (results[1].stdout as String).trim();
    final osVersion = (results[2].stdout as String).trim();
    final sdkStr = (results[3].stdout as String).trim();
    final wmOutput = (results[4].stdout as String).trim();
    final batteryOutput = (results[5].stdout as String).trim();

    final sdkVersion = int.tryParse(sdkStr) ?? 0;

    int screenWidth = 0, screenHeight = 0;
    final sizeMatch = RegExp(r'(\d+)x(\d+)').firstMatch(wmOutput);
    if (sizeMatch != null) {
      screenWidth = int.parse(sizeMatch.group(1)!);
      screenHeight = int.parse(sizeMatch.group(2)!);
    }

    int batteryLevel = -1;
    final levelMatch = RegExp(r'level: (\d+)').firstMatch(batteryOutput);
    if (levelMatch != null) {
      batteryLevel = int.parse(levelMatch.group(1)!);
    }

    String batteryStatus = 'unknown';
    final statusMatch = RegExp(r'status: (\d+)').firstMatch(batteryOutput);
    if (statusMatch != null) {
      switch (statusMatch.group(1)) {
        case '2': batteryStatus = 'charging';
        case '3': batteryStatus = 'discharging';
        case '5': batteryStatus = 'full';
      }
    }

    final connectionType = serial.startsWith('emulator-')
        ? 'emulator'
        : serial.contains(':')
            ? 'wifi'
            : 'usb';

    return Device(
      id: serial,
      serial: serial,
      model: model.isNotEmpty ? model : 'unknown',
      manufacturer: manufacturer.isNotEmpty ? manufacturer : 'unknown',
      osVersion: osVersion.isNotEmpty ? osVersion : 'unknown',
      sdkVersion: sdkVersion,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      batteryLevel: batteryLevel,
      batteryStatus: batteryStatus,
      connectionType: connectionType,
      status: 'connected',
      bridgeActive: false,
      platform: 'android',
      deviceType: connectionType == 'emulator' ? 'emulator' : 'physical',
    );
  }

  Future<bool> connectWifi(String ipPort) async {
    final result = await _adb.runGlobal(['connect', ipPort]);
    final output = (result.stdout as String).trim();
    if (output.contains('connected') || output.contains('already connected')) {
      await refreshDevices();
      return true;
    }
    return false;
  }

  Future<bool> enableWifiAdb(String usbSerial, {int port = AdbDefaults.wifiAdbPort}) async {
    await _adb.run(usbSerial, ['tcpip', '$port']);
    await Future.delayed(const Duration(seconds: 2));

    final ipResult = await _adb.run(
      usbSerial,
      ['shell', 'ip', 'route', 'show', 'dev', 'wlan0'],
    );
    final ipOutput = (ipResult.stdout as String).trim();
    final ipMatch = RegExp(r'src (\d+\.\d+\.\d+\.\d+)').firstMatch(ipOutput);

    if (ipMatch == null) return false;

    final ip = ipMatch.group(1)!;
    return connectWifi('$ip:$port');
  }

  /// Pair with device wirelessly (Android 11+)
  /// Requires: Developer Options → Wireless debugging → Pair with pairing code
  /// The device shows an IP:port and a 6-digit pairing code
  Future<bool> pairWireless(String ipPort, String pairingCode) async {
    final result = await _adb.runGlobal(['pair', ipPort, pairingCode]);
    final output = (result.stdout as String).trim() +
        (result.stderr as String).trim();
    if (output.contains('Successfully paired') || output.contains('paired')) {
      // After pairing, connect to the device's wireless debugging port
      // (different from the pairing port)
      await refreshDevices();
      return true;
    }
    return false;
  }

  Device? getDevice(String id) {
    try {
      return currentDevices.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  void startBridge(String deviceId) {
    _bridgedDeviceIds.add(deviceId);
    final updated = currentDevices.map((d) {
      if (d.id == deviceId) {
        return d.copyWith(status: 'bridged', bridgeActive: true);
      }
      return d;
    }).toList();
    _devices.add(updated);
  }

  void stopBridge(String deviceId) {
    _bridgedDeviceIds.remove(deviceId);
    final updated = currentDevices.map((d) {
      if (d.id == deviceId) {
        return d.copyWith(status: 'connected', bridgeActive: false);
      }
      return d;
    }).toList();
    _devices.add(updated);
  }

  void dispose() {
    _devices.close();
  }
}
