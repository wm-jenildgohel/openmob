import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
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
                  Icon(Iconsax.mobile, size: 64, color: ResColors.muted),
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
                            _buildQuickActionsCard(context, device),
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
                    _buildQuickActionsCard(context, device),
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

  Widget _buildQuickActionsCard(BuildContext context, Device device) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickActionButton(
                  icon: Iconsax.image,
                  label: 'Screenshot',
                  onTap: () async {
                    try {
                      final screenshot = await screenshotService.captureScreenshot(widget.deviceId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Screenshot captured (${screenshot.width}x${screenshot.height})')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Screenshot failed: $e')),
                        );
                      }
                    }
                  },
                ),
                _QuickActionButton(
                  icon: Iconsax.refresh,
                  label: 'Refresh',
                  onTap: () => deviceManager.refreshDevices(),
                ),
                _QuickActionButton(
                  icon: Iconsax.home_2,
                  label: 'Go Home',
                  onTap: () async {
                    try {
                      await actionService.goHome(widget.deviceId);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Go Home failed: $e')),
                        );
                      }
                    }
                  },
                ),
                _QuickActionButton(
                  icon: Iconsax.global,
                  label: 'Open URL',
                  onTap: () => _showOpenUrlDialog(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOpenUrlDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://example.com',
            labelText: 'URL',
          ),
          autofocus: true,
          onSubmitted: (_) {
            final url = controller.text.trim();
            if (url.isNotEmpty) {
              actionService.openUrl(widget.deviceId, url);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                actionService.openUrl(widget.deviceId, url);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Open'),
          ),
        ],
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

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hovering ? ResColors.accentSoft : ResColors.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovering ? ResColors.accent.withValues(alpha: 0.3) : ResColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: _hovering ? ResColors.accent : ResColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: _hovering ? ResColors.accent : ResColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
