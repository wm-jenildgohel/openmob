import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:rxdart_flutter/rxdart_flutter.dart';

import '../../core/res_colors.dart';
import '../../main.dart';
import '../../models/process_info.dart';
import 'pulse_dot.dart';

class ProcessControls extends StatelessWidget {
  const ProcessControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: _ProcessCard(
          title: 'MCP Server',
          subtitle: 'Device tools for AI agents',
          icon: Iconsax.cpu_charge,
          stream: processManager.mcpStatus$,
          onStart: () => processManager.startMcp(),
          onStop: () => processManager.stopMcp(),
          onRestart: () => processManager.restartMcp(),
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _ProcessCard(
          title: 'AiBridge',
          subtitle: 'AI Agent Bridge',
          icon: Iconsax.command_square,
          stream: processManager.bridgeStatus$,
          onStart: () => _showAgentPicker(context),
          onStop: () => processManager.stopBridge(),
          isOptional: true,
        )),
      ],
    );
  }

  void _showAgentPicker(BuildContext context) {
    final agents = processManager.availableAgents;
    if (agents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No supported AI agents found on this computer')),
      );
      return;
    }
    if (agents.length == 1) {
      processManager.startBridge(agent: agents.first);
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Agent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: agents
              .map((a) => ListTile(
                    leading: const Icon(Iconsax.command_square),
                    title: Text(a),
                    onTap: () {
                      Navigator.pop(ctx);
                      processManager.startBridge(agent: a);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueStream<ProcessInfo> stream;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback? onRestart;
  final bool isOptional;

  const _ProcessCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.stream,
    required this.onStart,
    required this.onStop,
    this.onRestart,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueStreamBuilder<ProcessInfo>(
      stream: stream,
      builder: (context, info, child) {
        final isRunning = info.status == ProcessStatus.running;
        final isStarting = info.status == ProcessStatus.starting;
        final isError = info.status == ProcessStatus.error;

        final statusColor = switch (info.status) {
          ProcessStatus.running => ResColors.running,
          ProcessStatus.starting => ResColors.warning,
          ProcessStatus.error => ResColors.error,
          ProcessStatus.stopped => ResColors.stopped,
        };

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ResColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isRunning
                  ? ResColors.accent.withValues(alpha: 0.3)
                  : ResColors.cardBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isRunning
                          ? ResColors.accentSoft
                          : ResColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon,
                        size: 18,
                        color: isRunning
                            ? ResColors.accent
                            : ResColors.textMuted),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(title,
                                style: const TextStyle(
                                  color: ResColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                )),
                            if (isOptional) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border:
                                      Border.all(color: ResColors.border),
                                ),
                                child: const Text('Optional',
                                    style: TextStyle(
                                      color: ResColors.textMuted,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: const TextStyle(
                              color: ResColors.textMuted,
                              fontSize: 11,
                            )),
                      ],
                    ),
                  ),
                  // Animated pulsing status dot with scale transition
                  _AnimatedStatusDot(
                    status: info.status,
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Status text
              Text(
                switch (info.status) {
                  ProcessStatus.running => 'Running',
                  ProcessStatus.stopped => 'Stopped',
                  ProcessStatus.starting => 'Starting...',
                  ProcessStatus.error => info.errorMessage ?? 'Error',
                },
                style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  _ActionButton(
                    label: 'Start',
                    icon: Iconsax.play,
                    onPressed: (isRunning || isStarting) ? null : onStart,
                    isPrimary: true,
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    label: 'Stop',
                    icon: Iconsax.stop,
                    onPressed: (isRunning || isError) ? onStop : null,
                  ),
                  if (onRestart != null) ...[
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: 'Restart',
                      icon: Iconsax.refresh,
                      onPressed: isRunning ? onRestart : null,
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Adds a subtle scale animation when process status changes.
class _AnimatedStatusDot extends StatefulWidget {
  final ProcessStatus status;
  final Color color;
  const _AnimatedStatusDot({required this.status, required this.color});

  @override
  State<_AnimatedStatusDot> createState() => _AnimatedStatusDotState();
}

class _AnimatedStatusDotState extends State<_AnimatedStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _scaleController.forward();
  }

  @override
  void didUpdateWidget(_AnimatedStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _scaleController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldAnimate = widget.status == ProcessStatus.running ||
        widget.status == ProcessStatus.starting;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: PulseDot(
        color: widget.color,
        size: 10,
        animate: shouldAnimate,
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isPrimary = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final bg = !enabled
        ? ResColors.bgSurface.withValues(alpha: 0.5)
        : widget.isPrimary
            ? (_hovering ? ResColors.accentHover : ResColors.accent)
            : (_hovering ? ResColors.bgSurface : ResColors.cardBg);
    final fg = !enabled
        ? ResColors.textMuted
        : widget.isPrimary
            ? ResColors.textOnAccent
            : ResColors.textSecondary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isPrimary && enabled
                  ? Colors.transparent
                  : ResColors.cardBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: fg),
              const SizedBox(width: 4),
              Text(widget.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
