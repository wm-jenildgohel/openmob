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

    return Device(
      id: serial,
      serial: serial,
      status: status == 'device' ? 'connected' : status,
      connectionType: connectionType,
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
    );
  }
}
