import 'package:flutter/material.dart';
import '../../core/res_colors.dart';

class ConnectionBadge extends StatelessWidget {
  final String connectionType;

  const ConnectionBadge({super.key, required this.connectionType});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _resolve(connectionType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  (Color, IconData, String) _resolve(String type) {
    return switch (type.toLowerCase()) {
      'usb' => (ResColors.usb, Icons.usb, 'USB'),
      'wifi' => (ResColors.wifi, Icons.wifi, 'WiFi'),
      'emulator' => (ResColors.emulator, Icons.phone_android, 'Emulator'),
      _ => (ResColors.muted, Icons.device_unknown, type),
    };
  }
}
