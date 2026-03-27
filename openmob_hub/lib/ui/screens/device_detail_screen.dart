import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/device.dart';
import '../widgets/connection_badge.dart';
import '../widgets/live_mirror.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;

  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  @override
  void dispose() {
    // Stop scrcpy stream when leaving device detail
    scrcpyStreamService.stopStream(widget.deviceId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueStreamBuilder<List<Device>>(
      stream: deviceManager.devices$,
      builder: (context, devices, child) {
        final device = devices.where((d) => d.id == widget.deviceId).firstOrNull;

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
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: LiveMirror(deviceSerial: device.serial),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMetadataCard(context, device),
                            const SizedBox(height: 16),
                            _buildBridgeCard(context, device),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 300,
                      child: LiveMirror(deviceSerial: device.serial),
                    ),
                    const SizedBox(height: 16),
                    _buildMetadataCard(context, device),
                    const SizedBox(height: 16),
                    _buildBridgeCard(context, device),
                  ],
                ),
              );
            },
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
            _infoRow('Device ID', device.serial),
            _infoRow('Brand', device.manufacturer),
            _infoRow('Operating System', '${device.platform == 'ios' ? 'iOS' : 'Android'} ${device.osVersion}'),
            _infoRow('Screen Size', '${device.screenWidth} x ${device.screenHeight}'),
            if (device.batteryLevel >= 0)
              _infoRow('Battery', '${device.batteryLevel}%'),
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
            Row(
              children: [
                Text('Device Automation', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Tooltip(
                  message: 'Enable this device for MCP tool control.\n'
                      'When active, AI agents can interact with this device.',
                  child: Icon(Icons.info_outline, size: 18, color: ResColors.muted),
                ),
              ],
            ),
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
                  device.bridgeActive ? 'Enabled - AI agents can control this device' : 'Disabled',
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
                  onPressed: device.bridgeActive
                      ? () => deviceManager.stopBridge(widget.deviceId)
                      : () => deviceManager.startBridge(widget.deviceId),
                  icon: Icon(device.bridgeActive ? Icons.stop : Icons.play_arrow),
                  label: Text(device.bridgeActive ? 'Disable' : 'Enable'),
                  style: device.bridgeActive
                      ? ElevatedButton.styleFrom(foregroundColor: ResColors.offline)
                      : null,
                ),
              ],
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
