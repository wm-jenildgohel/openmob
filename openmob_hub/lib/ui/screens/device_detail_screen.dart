import 'package:flutter/material.dart';

/// Placeholder -- full implementation in Task 2.
class DeviceDetailScreen extends StatelessWidget {
  final String deviceId;

  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Device $deviceId')),
      body: const Center(child: Text('Loading...')),
    );
  }
}
