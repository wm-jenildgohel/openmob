import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/device.dart';
import '../widgets/device_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _showPairDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _WirelessPairDialog(),
    );
  }

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
                    icon: const Icon(Iconsax.wifi, color: ResColors.accent),
                    tooltip: 'Pair device wirelessly',
                    onPressed: () => _showPairDialog(context),
                  ),
                  const SizedBox(width: 4),
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

// ─── Dialog state ───

enum _PairTab { pairNew, connectExisting }

enum _PairStatus { idle, loading, success, error }

class _PairState {
  final _PairStatus status;
  final String message;

  const _PairState({this.status = _PairStatus.idle, this.message = ''});

  _PairState copyWith({_PairStatus? status, String? message}) => _PairState(
        status: status ?? this.status,
        message: message ?? this.message,
      );
}

// ─── Wireless Pair Dialog ───

class _WirelessPairDialog extends StatefulWidget {
  const _WirelessPairDialog();

  @override
  State<_WirelessPairDialog> createState() => _WirelessPairDialogState();
}

class _WirelessPairDialogState extends State<_WirelessPairDialog> {
  final _pairIpController = TextEditingController();
  final _pairCodeController = TextEditingController();
  final _connectIpController = TextEditingController();

  final _activeTab$ = BehaviorSubject<_PairTab>.seeded(_PairTab.pairNew);
  final _state$ = BehaviorSubject<_PairState>.seeded(const _PairState());

  @override
  void dispose() {
    _pairIpController.dispose();
    _pairCodeController.dispose();
    _connectIpController.dispose();
    _activeTab$.close();
    _state$.close();
    super.dispose();
  }

  Future<void> _handlePair() async {
    final ip = _pairIpController.text.trim();
    final code = _pairCodeController.text.trim();
    if (ip.isEmpty || code.isEmpty) {
      _state$.add(const _PairState(
        status: _PairStatus.error,
        message: 'IP:port and pairing code are required',
      ));
      return;
    }
    _state$.add(const _PairState(status: _PairStatus.loading));
    try {
      final ok = await deviceManager.pairWireless(ip, code);
      if (ok) {
        _state$.add(const _PairState(
          status: _PairStatus.success,
          message: 'Paired successfully! Refreshing devices...',
        ));
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.of(context).pop();
      } else {
        _state$.add(const _PairState(
          status: _PairStatus.error,
          message: 'Pairing failed. Check IP:port and code.',
        ));
      }
    } catch (e) {
      _state$.add(_PairState(
        status: _PairStatus.error,
        message: 'Error: $e',
      ));
    }
  }

  Future<void> _handleConnect() async {
    final ip = _connectIpController.text.trim();
    if (ip.isEmpty) {
      _state$.add(const _PairState(
        status: _PairStatus.error,
        message: 'IP:port is required',
      ));
      return;
    }
    _state$.add(const _PairState(status: _PairStatus.loading));
    try {
      final ok = await deviceManager.connectWifi(ip);
      if (ok) {
        _state$.add(const _PairState(
          status: _PairStatus.success,
          message: 'Connected! Refreshing devices...',
        ));
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.of(context).pop();
      } else {
        _state$.add(const _PairState(
          status: _PairStatus.error,
          message: 'Connection failed. Is the device reachable?',
        ));
      }
    } catch (e) {
      _state$.add(_PairState(
        status: _PairStatus.error,
        message: 'Error: $e',
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: ResColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: ResColors.border),
      ),
      child: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  const Icon(Iconsax.wifi, color: ResColors.accent, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Connect Device Wirelessly',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ResColors.textPrimary,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: ResColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 16,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tab selector
              ValueStreamBuilder<_PairTab>(
                stream: _activeTab$,
                builder: (context, tab, _) {
                  return Row(
                    children: [
                      _buildTab(
                        label: 'Pair New (Android 11+)',
                        isActive: tab == _PairTab.pairNew,
                        onTap: () {
                          _activeTab$.add(_PairTab.pairNew);
                          _state$.add(const _PairState());
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildTab(
                        label: 'Connect Existing',
                        isActive: tab == _PairTab.connectExisting,
                        onTap: () {
                          _activeTab$.add(_PairTab.connectExisting);
                          _state$.add(const _PairState());
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Tab content
              ValueStreamBuilder<_PairTab>(
                stream: _activeTab$,
                builder: (context, tab, _) {
                  if (tab == _PairTab.pairNew) {
                    return _buildPairNewSection();
                  }
                  return _buildConnectExistingSection();
                },
              ),

              const SizedBox(height: 16),

              // Status feedback
              ValueStreamBuilder<_PairState>(
                stream: _state$,
                builder: (context, state, _) {
                  if (state.status == _PairStatus.idle) {
                    return const SizedBox.shrink();
                  }
                  return _buildStatusBar(state);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? ResColors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? ResColors.accent : ResColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? ResColors.accent : ResColors.textSecondary,
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPairNewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ResColors.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Iconsax.info_circle,
                  size: 16, color: ResColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'On your phone: Settings \u2192 Developer Options '
                  '\u2192 Wireless Debugging \u2192 Pair with pairing code',
                  style: TextStyle(
                    color: ResColors.accent,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _pairIpController,
          label: 'IP:Port',
          hint: '192.168.1.100:37123',
          icon: Iconsax.global,
        ),
        const SizedBox(height: 10),
        _buildTextField(
          controller: _pairCodeController,
          label: 'Pairing Code',
          hint: '123456',
          icon: Iconsax.key,
        ),
        const SizedBox(height: 14),
        _buildActionButton(
          label: 'Pair Device',
          icon: Iconsax.link_21,
          onPressed: _handlePair,
        ),
      ],
    );
  }

  Widget _buildConnectExistingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ResColors.accentSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Iconsax.info_circle,
                  size: 16, color: ResColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'For already-paired or older devices. Use the '
                  'IP:port shown under Wireless Debugging on the device.',
                  style: TextStyle(
                    color: ResColors.accent,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _connectIpController,
          label: 'IP:Port',
          hint: '192.168.1.100:5555',
          icon: Iconsax.global,
        ),
        const SizedBox(height: 14),
        _buildActionButton(
          label: 'Connect',
          icon: Iconsax.wifi,
          onPressed: _handleConnect,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: ResColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: ResColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: ResColors.textMuted, fontSize: 14),
            prefixIcon: Icon(icon, size: 18, color: ResColors.textMuted),
            filled: true,
            fillColor: ResColors.bgSurface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ResColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ResColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ResColors.accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ValueStreamBuilder<_PairState>(
      stream: _state$,
      builder: (context, state, _) {
        final isLoading = state.status == _PairStatus.loading;
        return SizedBox(
          width: double.infinity,
          child: MouseRegion(
            cursor:
                isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
            child: GestureDetector(
              onTap: isLoading ? null : onPressed,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isLoading
                      ? ResColors.accent.withValues(alpha: 0.5)
                      : ResColors.accent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isLoading
                      ? null
                      : [
                          BoxShadow(
                            color: ResColors.accent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: ResColors.textOnAccent,
                        ),
                      )
                    else
                      Icon(icon, size: 16, color: ResColors.textOnAccent),
                    const SizedBox(width: 8),
                    Text(
                      isLoading ? 'Connecting...' : label,
                      style: const TextStyle(
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
        );
      },
    );
  }

  Widget _buildStatusBar(_PairState state) {
    final Color bgColor;
    final Color textColor;
    final IconData icon;

    switch (state.status) {
      case _PairStatus.loading:
        bgColor = ResColors.accentSoft;
        textColor = ResColors.accent;
        icon = Iconsax.timer_1;
      case _PairStatus.success:
        bgColor = const Color(0x1A22C55E);
        textColor = ResColors.connected;
        icon = Iconsax.tick_circle;
      case _PairStatus.error:
        bgColor = const Color(0x1AEF4444);
        textColor = ResColors.error;
        icon = Iconsax.warning_2;
      case _PairStatus.idle:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.message,
              style: TextStyle(color: textColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
