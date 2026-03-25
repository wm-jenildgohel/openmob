import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/device.dart';
import '../widgets/sidebar.dart';
import '../widgets/process_controls.dart';
import 'home_screen.dart';
import 'logs_screen.dart';
import 'system_check_screen.dart';
import 'testing_screen.dart';

final _navIndex = BehaviorSubject<int>.seeded(0);

class DashboardShell extends StatelessWidget {
  const DashboardShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ResColors.bg,
      body: ValueStreamBuilder<int>(
        stream: _navIndex.stream,
        builder: (context, index, child) {
          return Row(
            children: [
              Sidebar(
                selectedIndex: index,
                onDestinationSelected: (i) => _navIndex.add(i),
              ),
              Expanded(
                child: _buildContent(context, index),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, int index) {
    return switch (index) {
      0 => _buildDashboard(context),
      1 => const HomeScreen(),
      2 => const LogsScreen(),
      3 => const TestingScreen(),
      4 => const SystemCheckScreen(),
      _ => _buildDashboard(context),
    };
  }

  Widget _buildDashboard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard', style: textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Manage processes and connected devices',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
              const Spacer(),
              // Status indicator
              _buildApiStatus(),
            ],
          ),
          const SizedBox(height: 24),

          // Process controls
          const ProcessControls(),
          const SizedBox(height: 32),

          // Devices header
          Row(
            children: [
              const Icon(Icons.phone_android_rounded, size: 20, color: ResColors.textSecondary),
              const SizedBox(width: 8),
              Text('Connected Devices', style: textTheme.titleMedium),
              const SizedBox(width: 12),
              ValueStreamBuilder<List<Device>>(
                stream: deviceManager.devices$,
                builder: (context, devices, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: devices.isNotEmpty ? ResColors.accentSoft : ResColors.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: devices.isNotEmpty
                            ? ResColors.accent.withValues(alpha: 0.3)
                            : ResColors.cardBorder,
                      ),
                    ),
                    child: Text(
                      '${devices.length}',
                      style: TextStyle(
                        color: devices.isNotEmpty ? ResColors.accent : ResColors.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Device list
          Expanded(
            child: ValueStreamBuilder<List<Device>>(
              stream: deviceManager.devices$,
              builder: (context, devices, child) {
                if (devices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: ResColors.bgSurface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.phone_android_rounded,
                            size: 32,
                            color: ResColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No devices connected',
                          style: textTheme.titleMedium?.copyWith(color: ResColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connect a device via USB or start an emulator',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: devices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return _DeviceRow(device: device);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ResColors.accentSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ResColors.accent.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: ResColors.accent),
          SizedBox(width: 6),
          Text(
            'Hub Online',
            style: TextStyle(
              color: ResColors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatefulWidget {
  final Device device;
  const _DeviceRow({required this.device});

  @override
  State<_DeviceRow> createState() => _DeviceRowState();
}

class _DeviceRowState extends State<_DeviceRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final statusColor = switch (device.status.toLowerCase()) {
      'connected' => ResColors.connected,
      'bridged' => ResColors.bridged,
      _ => ResColors.stopped,
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/device/${device.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _hovering ? ResColors.cardHover : ResColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering ? ResColors.border : ResColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              // Device icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ResColors.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  device.platform == 'ios'
                      ? Icons.phone_iphone_rounded
                      : Icons.phone_android_rounded,
                  color: ResColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.model,
                      style: const TextStyle(
                        color: ResColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device.manufacturer} \u2022 ${device.osVersion} \u2022 ${device.screenWidth}x${device.screenHeight}',
                      style: const TextStyle(
                        color: ResColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Connection badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ResColors.bgSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  device.connectionType.toUpperCase(),
                  style: const TextStyle(
                    color: ResColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Status dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _hovering ? ResColors.textSecondary : ResColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
