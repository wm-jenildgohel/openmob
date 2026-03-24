import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/device.dart';
import '../widgets/connection_badge.dart';

class DeviceDetailScreen extends StatelessWidget {
  final String deviceId;

  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return ValueStreamBuilder<List<Device>>(
      stream: deviceManager.devices$,
      builder: (context, devices, child) {
        final device = devices.where((d) => d.id == deviceId).firstOrNull;

        if (device == null) {
          return Scaffold(
            appBar: AppBar(
              leading: const BackButton(),
              title: const Text('Device'),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phonelink_erase, size: 64, color: ResColors.muted),
                  const SizedBox(height: 16),
                  const Text('Device disconnected'),
                  const SizedBox(height: 8),
                  Text(
                    'This device is no longer available',
                    style: TextStyle(color: ResColors.muted),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: Row(
              children: [
                Text(
                  device.model,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                ConnectionBadge(connectionType: device.connectionType),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetadataCard(context, device),
                const SizedBox(height: 16),
                _buildBridgeCard(context, device),
                const SizedBox(height: 16),
                _buildApiInfoCard(context, device),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetadataCard(BuildContext context, Device device) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device Information', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow('Serial', device.serial),
            _infoRow('Manufacturer', device.manufacturer),
            _infoRow('OS Version', 'Android ${device.osVersion} (SDK ${device.sdkVersion})'),
            _infoRow('Screen', '${device.screenWidth}x${device.screenHeight}'),
            _infoRow('Battery', '${device.batteryLevel}% (${device.batteryStatus})'),
            _infoRow('Connection', device.connectionType),
            _statusRow('Status', device.status),
          ],
        ),
      ),
    );
  }

  Widget _buildBridgeCard(BuildContext context, Device device) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Automation Bridge', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: device.bridgeActive ? ResColors.connected : ResColors.offline,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  device.bridgeActive ? 'Active' : 'Inactive',
                  style: textTheme.bodyMedium?.copyWith(
                    color: device.bridgeActive ? ResColors.connected : ResColors.offline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: device.bridgeActive ? null : () => deviceManager.startBridge(deviceId),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Bridge'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: device.bridgeActive ? () => deviceManager.stopBridge(deviceId) : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop Bridge'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: ResColors.offline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiInfoCard(BuildContext context, Device device) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API Endpoints', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SelectableText(
              'curl localhost:8686/api/v1/devices/${device.id}/screenshot',
              style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            SelectableText(
              'curl localhost:8686/api/v1/devices/${device.id}/ui-tree',
              style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            SelectableText(
              'curl -X POST localhost:8686/api/v1/devices/${device.id}/tap -d \'{"x":540,"y":1200}\'',
              style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: ResColors.muted, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String status) {
    final color = switch (status.toLowerCase()) {
      'connected' => ResColors.connected,
      'offline' => ResColors.offline,
      'bridged' => ResColors.bridged,
      _ => ResColors.muted,
    };
    final displayStatus = status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : status;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: ResColors.muted, fontWeight: FontWeight.w500)),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(displayStatus, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
