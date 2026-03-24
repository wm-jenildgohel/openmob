import 'package:flutter/material.dart';
import '../../core/res_colors.dart';
import '../../models/device.dart';
import 'connection_badge.dart';

class DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback? onTap;

  const DeviceCard({super.key, required this.device, this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Model + connection badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      device.model,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ConnectionBadge(connectionType: device.connectionType),
                ],
              ),
              const SizedBox(height: 8),

              // Manufacturer + OS
              Text(
                '${device.manufacturer} | Android ${device.osVersion}',
                style: textTheme.bodyMedium?.copyWith(color: ResColors.muted),
              ),
              const SizedBox(height: 4),

              // Screen + Battery
              Text(
                '${device.screenWidth}x${device.screenHeight} | Battery: ${device.batteryLevel}%',
                style: textTheme.bodySmall?.copyWith(color: ResColors.muted),
              ),
              const SizedBox(height: 8),

              // Status
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _statusColor(device.status),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _capitalize(device.status),
                    style: textTheme.bodySmall?.copyWith(
                      color: _statusColor(device.status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'connected' => ResColors.connected,
      'offline' => ResColors.offline,
      'bridged' => ResColors.bridged,
      _ => ResColors.muted,
    };
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
