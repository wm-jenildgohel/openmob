import 'package:flutter/material.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/device.dart';
import '../widgets/device_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueStreamBuilder<List<Device>>(
        stream: deviceManager.devices$,
        builder: (context, devices, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Connected Devices',
                    style: textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ResColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${devices.length}',
                      style: const TextStyle(
                        color: ResColors.textOnAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh devices',
                    onPressed: () => deviceManager.refreshDevices(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (devices.isEmpty)
                const Expanded(child: _HomeEmptyState())
              else
                Expanded(
                  child: _StaggeredDeviceGrid(devices: devices),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Empty state with floating icon and gradient text.
class _HomeEmptyState extends StatefulWidget {
  const _HomeEmptyState();

  @override
  State<_HomeEmptyState> createState() => _HomeEmptyStateState();
}

class _HomeEmptyStateState extends State<_HomeEmptyState>
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
            child: Icon(Icons.phone_android, size: 64, color: ResColors.muted),
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
            'Connect an Android device via USB, WiFi ADB, or start an emulator',
            style: TextStyle(color: ResColors.muted),
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

/// Staggered entrance animation for device grid items.
class _StaggeredDeviceGrid extends StatefulWidget {
  final List<Device> devices;
  const _StaggeredDeviceGrid({required this.devices});

  @override
  State<_StaggeredDeviceGrid> createState() => _StaggeredDeviceGridState();
}

class _StaggeredDeviceGridState extends State<_StaggeredDeviceGrid>
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
  void didUpdateWidget(_StaggeredDeviceGrid oldWidget) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 600
                    ? 2
                    : 1;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 2.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: widget.devices.length,
          itemBuilder: (context, index) {
            final totalDuration =
                200 + widget.devices.length * 50;
            final startInterval =
                (index * 50) / totalDuration;
            final endInterval =
                startInterval + 200 / totalDuration;

            final itemAnimation =
                Tween<double>(begin: 0, end: 1).animate(
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
              child: DeviceCard(
                device: widget.devices[index],
                onTap: () => Navigator.pushNamed(
                  context,
                  '/device/${widget.devices[index].id}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
