class Device {
  final String id;
  final String serial;
  final String model;
  final String manufacturer;
  final String osVersion;
  final int sdkVersion;
  final int screenWidth;
  final int screenHeight;
  final int batteryLevel;
  final String batteryStatus;
  final String connectionType;
  final String status;
  final bool bridgeActive;
  final String platform;    // 'android' or 'ios'
  final String deviceType;  // 'physical', 'emulator', 'simulator'

  const Device({
    required this.id,
    required this.serial,
    this.model = 'unknown',
    this.manufacturer = 'unknown',
    this.osVersion = 'unknown',
    this.sdkVersion = 0,
    this.screenWidth = 0,
    this.screenHeight = 0,
    this.batteryLevel = -1,
    this.batteryStatus = 'unknown',
    this.connectionType = 'usb',
    this.status = 'connected',
    this.bridgeActive = false,
    this.platform = 'android',
    this.deviceType = 'physical',
  });

  factory Device.fromAdb({
    required String serial,
    required String status,
  }) {
    final connectionType = serial.startsWith('emulator-')
        ? 'emulator'
        : serial.contains(':')
            ? 'wifi'
            : 'usb';

    final deviceType = connectionType == 'emulator' ? 'emulator' : 'physical';

    return Device(
      id: serial,
      serial: serial,
      status: status == 'device' ? 'connected' : status,
      connectionType: connectionType,
      platform: 'android',
      deviceType: deviceType,
    );
  }

  /// Create a Device from xcrun simctl output.
  /// [runtime] is e.g. 'com.apple.CoreSimulator.SimRuntime.iOS-17-5' -> '17.5'
  factory Device.fromSimctl({
    required String udid,
    required String name,
    required String state,
    required String runtime,
    required String deviceTypeId,
  }) {
    // Extract OS version from runtime string
    // e.g. 'com.apple.CoreSimulator.SimRuntime.iOS-17-5' -> '17.5'
    String osVersion = 'unknown';
    final rtMatch = RegExp(r'iOS[.-](\d+)[.-](\d+)').firstMatch(runtime);
    if (rtMatch != null) {
      osVersion = '${rtMatch.group(1)}.${rtMatch.group(2)}';
    }

    return Device(
      id: udid,
      serial: udid,
      model: name,
      manufacturer: 'Apple',
      osVersion: osVersion,
      connectionType: 'simulator',
      status: state == 'Booted' ? 'connected' : 'disconnected',
      platform: 'ios',
      deviceType: 'simulator',
    );
  }

  Device copyWith({
    String? id,
    String? serial,
    String? model,
    String? manufacturer,
    String? osVersion,
    int? sdkVersion,
    int? screenWidth,
    int? screenHeight,
    int? batteryLevel,
    String? batteryStatus,
    String? connectionType,
    String? status,
    bool? bridgeActive,
    String? platform,
    String? deviceType,
  }) {
    return Device(
      id: id ?? this.id,
      serial: serial ?? this.serial,
      model: model ?? this.model,
      manufacturer: manufacturer ?? this.manufacturer,
      osVersion: osVersion ?? this.osVersion,
      sdkVersion: sdkVersion ?? this.sdkVersion,
      screenWidth: screenWidth ?? this.screenWidth,
      screenHeight: screenHeight ?? this.screenHeight,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      batteryStatus: batteryStatus ?? this.batteryStatus,
      connectionType: connectionType ?? this.connectionType,
      status: status ?? this.status,
      bridgeActive: bridgeActive ?? this.bridgeActive,
      platform: platform ?? this.platform,
      deviceType: deviceType ?? this.deviceType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serial': serial,
      'model': model,
      'manufacturer': manufacturer,
      'osVersion': osVersion,
      'sdkVersion': sdkVersion,
      'screenWidth': screenWidth,
      'screenHeight': screenHeight,
      'batteryLevel': batteryLevel,
      'batteryStatus': batteryStatus,
      'connectionType': connectionType,
      'status': status,
      'bridgeActive': bridgeActive,
      'platform': platform,
      'deviceType': deviceType,
    };
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      serial: json['serial'] as String,
      model: json['model'] as String? ?? 'unknown',
      manufacturer: json['manufacturer'] as String? ?? 'unknown',
      osVersion: json['osVersion'] as String? ?? 'unknown',
      sdkVersion: json['sdkVersion'] as int? ?? 0,
      screenWidth: json['screenWidth'] as int? ?? 0,
      screenHeight: json['screenHeight'] as int? ?? 0,
      batteryLevel: json['batteryLevel'] as int? ?? -1,
      batteryStatus: json['batteryStatus'] as String? ?? 'unknown',
      connectionType: json['connectionType'] as String? ?? 'usb',
      status: json['status'] as String? ?? 'connected',
      bridgeActive: json['bridgeActive'] as bool? ?? false,
      platform: json['platform'] as String? ?? 'android',
      deviceType: json['deviceType'] as String? ?? 'physical',
    );
  }
}
