import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../models/device.dart';
import '../core/constants.dart';
import 'adb_service.dart';

class DeviceManager {
  final AdbService _adb;

  DeviceManager(this._adb);

  final _devices = BehaviorSubject<List<Device>>.seeded([]);

  ValueStream<List<Device>> get devices$ => _devices.stream;

  List<Device> get currentDevices => _devices.value;

  Future<void> refreshDevices() async {
    final rawDevices = await _adb.listRawDevices();
    final enriched = <Device>[];

    for (final raw in rawDevices) {
      if (raw.status == 'device') {
        try {
          final device = await _enrichDevice(raw.serial);
          enriched.add(device);
        } catch (_) {
          // If enrichment fails, add a basic device entry
          enriched.add(Device.fromAdb(serial: raw.serial, status: raw.status));
        }
      } else {
        enriched.add(Device.fromAdb(serial: raw.serial, status: raw.status));
      }
    }

    _devices.add(enriched);
  }

  Future<Device> _enrichDevice(String serial) async {
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

    // Parse SDK version
    final sdkVersion = int.tryParse(sdkStr) ?? 0;

    // Parse screen size from "Physical size: 1080x1920"
    int screenWidth = 0;
    int screenHeight = 0;
    final sizeMatch = RegExp(r'(\d+)x(\d+)').firstMatch(wmOutput);
    if (sizeMatch != null) {
      screenWidth = int.parse(sizeMatch.group(1)!);
      screenHeight = int.parse(sizeMatch.group(2)!);
    }

    // Parse battery level from "level: 85"
    int batteryLevel = -1;
    final levelMatch = RegExp(r'level: (\d+)').firstMatch(batteryOutput);
    if (levelMatch != null) {
      batteryLevel = int.parse(levelMatch.group(1)!);
    }

    // Parse battery status from "status: 2"
    // 2=charging, 3=discharging, 5=full
    String batteryStatus = 'unknown';
    final statusMatch = RegExp(r'status: (\d+)').firstMatch(batteryOutput);
    if (statusMatch != null) {
      switch (statusMatch.group(1)) {
        case '2':
          batteryStatus = 'charging';
          break;
        case '3':
          batteryStatus = 'discharging';
          break;
        case '5':
          batteryStatus = 'full';
          break;
        default:
          batteryStatus = 'unknown';
      }
    }

    // Determine connection type
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

  Device? getDevice(String id) {
    try {
      return currentDevices.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  void startBridge(String deviceId) {
    final updated = currentDevices.map((d) {
      if (d.id == deviceId) {
        return d.copyWith(status: 'bridged', bridgeActive: true);
      }
      return d;
    }).toList();
    _devices.add(updated);
  }

  void stopBridge(String deviceId) {
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
