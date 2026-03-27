import 'package:flutter/material.dart';
import '../../core/res_colors.dart';

/// Animated pulsing status dot for connected/running/bridged states.
/// Static dot for stopped/offline states.
class PulseDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool animate;

  const PulseDot({
    super.key,
    this.color = ResColors.connected,
    this.size = 8,
    this.animate = true,
  });

  /// Green pulsing dot for "connected" status.
  const PulseDot.connected({super.key, this.size = 8})
      : color = ResColors.connected,
        animate = true;

  /// Blue pulsing dot for "bridged" status.
  const PulseDot.bridged({super.key, this.size = 8})
      : color = ResColors.bridged,
        animate = true;

  /// Static dot for stopped/offline states.
  const PulseDot.stopped({super.key, this.size = 8})
      : color = ResColors.stopped,
        animate = false;

  /// Factory to pick the right variant from a status string.
  factory PulseDot.fromStatus(String status, {double size = 8}) {
    return switch (status.toLowerCase()) {
      'connected' || 'running' => PulseDot(
          color: ResColors.connected, size: size, animate: true),
      'bridged' => PulseDot(
          color: ResColors.bridged, size: size, animate: true),
      'starting' => PulseDot(
          color: ResColors.warning, size: size, animate: true),
      'error' => PulseDot(
          color: ResColors.error, size: size, animate: false),
      _ => PulseDot(
          color: ResColors.stopped, size: size, animate: false),
    };
  }

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
    // If color changed, trigger repaint
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animation.value * 0.6),
                blurRadius: widget.size * _animation.value,
                spreadRadius: widget.size * 0.2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
