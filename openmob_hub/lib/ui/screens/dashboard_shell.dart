import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/device.dart';
import '../widgets/pulse_dot.dart';
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
                child: _AnimatedPageSwitcher(index: index),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tracks previous index to determine slide direction.
class _AnimatedPageSwitcher extends StatefulWidget {
  final int index;
  const _AnimatedPageSwitcher({required this.index});

  @override
  State<_AnimatedPageSwitcher> createState() => _AnimatedPageSwitcherState();
}

class _AnimatedPageSwitcherState extends State<_AnimatedPageSwitcher> {
  int _previousIndex = 0;

  @override
  void didUpdateWidget(_AnimatedPageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _previousIndex = oldWidget.index;
    }
  }

  Widget _buildContent(int index) {
    return switch (index) {
      0 => const _DashboardContent(),
      1 => const HomeScreen(),
      2 => const LogsScreen(),
      3 => const TestingScreen(),
      4 => const SystemCheckScreen(),
      _ => const _DashboardContent(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final goingForward = widget.index > _previousIndex;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) {
        final offsetBegin = goingForward
            ? const Offset(0.05, 0)
            : const Offset(-0.05, 0);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: offsetBegin,
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(widget.index),
        child: _buildContent(widget.index),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent();

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.phone_android_rounded,
                  size: 20, color: ResColors.textSecondary),
              const SizedBox(width: 8),
              Text('Connected Devices', style: textTheme.titleMedium),
              const SizedBox(width: 12),
              ValueStreamBuilder<List<Device>>(
                stream: deviceManager.devices$,
                builder: (context, devices, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: devices.isNotEmpty
                          ? ResColors.accentSoft
                          : ResColors.bgSurface,
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
                        color: devices.isNotEmpty
                            ? ResColors.accent
                            : ResColors.textMuted,
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
                  return const _EmptyDeviceState();
                }

                return _StaggeredDeviceList(devices: devices);
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
          PulseDot.connected(size: 8),
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

/// Empty state with floating phone icon animation and gradient text.
class _EmptyDeviceState extends StatefulWidget {
  const _EmptyDeviceState();

  @override
  State<_EmptyDeviceState> createState() => _EmptyDeviceStateState();
}

class _EmptyDeviceStateState extends State<_EmptyDeviceState>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: child,
              );
            },
            child: Container(
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
          ),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [ResColors.accent, ResColors.bridged],
            ).createShader(bounds),
            child: Text(
              'No devices connected',
              style: textTheme.titleMedium?.copyWith(
                color: ResColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect a device via USB or start an emulator',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => deviceManager.refreshDevices(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: ResColors.accent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: ResColors.accent.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        size: 16, color: ResColors.textOnAccent),
                    SizedBox(width: 8),
                    Text(
                      'Scan for Devices',
                      style: TextStyle(
                        color: ResColors.textOnAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Staggered entrance animation for device list items.
class _StaggeredDeviceList extends StatefulWidget {
  final List<Device> devices;
  const _StaggeredDeviceList({required this.devices});

  @override
  State<_StaggeredDeviceList> createState() => _StaggeredDeviceListState();
}

class _StaggeredDeviceListState extends State<_StaggeredDeviceList>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 200 + (widget.devices.length * 50),
      ),
    )..forward();
  }

  @override
  void didUpdateWidget(_StaggeredDeviceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.devices.length != widget.devices.length) {
      _staggerController.duration = Duration(
        milliseconds: 200 + (widget.devices.length * 50),
      );
      _staggerController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: widget.devices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final device = widget.devices[index];
        final startInterval =
            (index * 50) / (200 + widget.devices.length * 50);
        final endInterval = startInterval + 200 / (200 + widget.devices.length * 50);

        final itemAnimation = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: _staggerController,
            curve: Interval(
              startInterval.clamp(0.0, 1.0),
              endInterval.clamp(0.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
          ),
        );

        return AnimatedBuilder(
          animation: itemAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: itemAnimation.value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - itemAnimation.value)),
                child: child,
              ),
            );
          },
          child: _DeviceRow(device: device),
        );
      },
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
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: ResColors.bg.withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              // Pulsing status dot
              PulseDot.fromStatus(device.status, size: 8),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color:
                    _hovering ? ResColors.textSecondary : ResColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
