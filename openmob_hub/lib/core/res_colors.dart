import 'package:flutter/material.dart';

class ResColors {
  ResColors._();

  // Connection type colors
  static const Color usb = Colors.blue;
  static const Color wifi = Colors.green;
  static const Color emulator = Colors.orange;

  // Status colors
  static const Color connected = Colors.green;
  static const Color offline = Colors.red;
  static const Color bridged = Colors.blue;

  // General
  static const Color muted = Colors.grey;
  static const Color surface = Color(0xFF1E1E1E);
  static const Color cardBorder = Color(0xFF2A2A2A);

  // Process status
  static const Color running = Color(0xFF4CAF50);
  static const Color stopped = Color(0xFF9E9E9E);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);

  // Log viewer
  static const Color logBg = Color(0xFF121212);

  // Sidebar
  static const Color sidebar = Color(0xFF161616);
  static const Color sidebarActive = Color(0xFF1E1E1E);

  // Accent
  static const Color accent = Color(0xFF2196F3);

  // Testing
  static const Color testPassed = Color(0xFF4CAF50);
  static const Color testFailed = Color(0xFFF44336);
  static const Color testRunning = Color(0xFF2196F3);
  static const Color testSkipped = Color(0xFF9E9E9E);
}
