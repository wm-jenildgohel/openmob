import 'package:flutter/material.dart';
import '../../core/res_colors.dart';
import '../../models/device.dart';
import 'connection_badge.dart';
import 'pulse_dot.dart';

class DeviceCard extends StatefulWidget {
  final Device device;
  final VoidCallback? onTap;

  const DeviceCard({super.key, required this.device, this.onTap});

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  bool _hovering = false;

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'connected' => ResColors.connected,
      'offline' => ResColors.offline,
      'bridged' => ResColors.bridged,
      _ => ResColors.muted,
    };
  }

  List<Color> _accentGradient(String status) {
    return switch (status.toLowerCase()) {
      'connected' => [ResColors.connected, ResColors.connected.withValues(alpha: 0.4)],
      'bridged' => [ResColors.bridged, ResColors.bridged.withValues(alpha: 0.4)],
      'offline' => [ResColors.offline, ResColors.offline.withValues(alpha: 0.4)],
      _ => [ResColors.stopped, ResColors.stopped.withValues(alpha: 0.4)],
    };
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final device = widget.device;
    final gradient = _accentGradient(device.status);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovering ? ResColors.cardHover : ResColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering ? ResColors.border : ResColors.cardBorder,
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: ResColors.bg.withValues(alpha: 0.6),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thin accent gradient bar at top
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    topRight: Radius.circular(11),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Model + connection badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              device.model,
                              style: textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ConnectionBadge(
                              connectionType: device.connectionType),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Manufacturer + OS
                      Text(
                        '${device.manufacturer} | ${device.platform == 'ios' ? 'iOS' : 'Android'} ${device.osVersion}',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: ResColors.muted),
                      ),
                      const SizedBox(height: 4),

                      // Screen
                      Text(
                        '${device.screenWidth}x${device.screenHeight}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: ResColors.muted),
                      ),

                      const Spacer(),

                      // Battery bar + Status row
                      Row(
                        children: [
                          // Battery indicator
                          if (device.batteryLevel >= 0) ...[
                            _BatteryIndicator(level: device.batteryLevel),
                            const SizedBox(width: 12),
                          ],
                          // Status with pulsing dot
                          PulseDot.fromStatus(device.status, size: 8),
                          const SizedBox(width: 6),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact horizontal battery level indicator.
class _BatteryIndicator extends StatelessWidget {
  final int level;
  const _BatteryIndicator({required this.level});

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(0, 100);
    final color = clampedLevel <= 20
        ? ResColors.error
        : clampedLevel <= 50
            ? ResColors.warning
            : ResColors.connected;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: ResColors.border, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.5),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clampedLevel / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$clampedLevel%',
          style: const TextStyle(
            color: ResColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
