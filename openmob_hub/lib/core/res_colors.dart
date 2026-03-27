import 'package:flutter/material.dart';

/// OpenMob color palette — derived from the logo (blue + orange gradient)
/// Dark theme with blue primary and orange accent for CTAs/actions
class ResColors {
  ResColors._();

  // ─── Base palette (dark theme) ───
  static const Color bg = Color(0xFF0D1B2A);            // Deep navy — main background
  static const Color bgElevated = Color(0xFF1B2D45);     // Navy 800 — cards, elevated
  static const Color bgSurface = Color(0xFF253B56);       // Navy 700 — inputs, hover
  static const Color border = Color(0xFF344E68);          // Navy 600 — borders
  static const Color borderSubtle = Color(0xFF253B56);    // Navy 700 — subtle borders

  // ─── Text ───
  static const Color textPrimary = Color(0xFFF0F4F8);    // Near white — headings
  static const Color textSecondary = Color(0xFF8DA4BF);   // Slate blue — secondary
  static const Color textMuted = Color(0xFF5B7A99);       // Muted blue — hints
  static const Color textOnAccent = Color(0xFFFFFFFF);    // White — on colored buttons

  // ─── Primary (Blue — from logo) ───
  static const Color primary = Color(0xFF3B9FE8);         // Bright blue — primary actions
  static const Color primaryDark = Color(0xFF1A5BA5);     // Deep blue — hover state
  static const Color primarySoft = Color(0x1A3B9FE8);    // Blue @ 10% — soft bg
  static const Color primaryLight = Color(0xFF4DC9F6);    // Cyan — highlights

  // ─── Accent (Orange — from logo CTA) ───
  static const Color accent = Color(0xFFE87B2F);          // Orange — CTA, important actions
  static const Color accentHover = Color(0xFFD06A25);     // Darker orange — hover
  static const Color accentSoft = Color(0x1AE87B2F);     // Orange @ 10% — soft bg
  static const Color accentBright = Color(0xFFF5A623);    // Bright orange — highlights

  // ─── Status ───
  static const Color connected = Color(0xFF22C55E);       // Green 500
  static const Color running = Color(0xFF22C55E);         // Green 500
  static const Color warning = Color(0xFFF5A623);         // Logo orange (warm warning)
  static const Color error = Color(0xFFEF4444);           // Red 500
  static const Color stopped = Color(0xFF5B7A99);         // Muted blue
  static const Color offline = Color(0xFFEF4444);         // Red 500
  static const Color bridged = Color(0xFF3B9FE8);         // Logo blue

  // ─── Connection types ───
  static const Color usb = Color(0xFF3B9FE8);             // Logo blue
  static const Color wifi = Color(0xFF22C55E);            // Green
  static const Color emulator = Color(0xFFF5A623);        // Logo orange

  // ─── Sidebar ───
  static const Color sidebar = Color(0xFF081525);         // Deepest navy
  static const Color sidebarActive = Color(0xFF1B2D45);   // Elevated on active
  static const Color sidebarIcon = Color(0xFF5B7A99);     // Muted blue icons
  static const Color sidebarIconActive = Color(0xFF3B9FE8); // Logo blue on active

  // ─── Cards ───
  static const Color cardBg = Color(0xFF1B2D45);          // Navy 800
  static const Color cardBorder = Color(0xFF253B56);      // Navy 700
  static const Color cardHover = Color(0xFF213A54);       // Slightly lighter

  // ─── Log viewer ───
  static const Color logBg = Color(0xFF081525);           // Deepest navy
  static const Color logText = Color(0xFFB0C4DB);         // Light blue-gray
  static const Color logWarning = Color(0xFFF5A623);      // Orange
  static const Color logError = Color(0xFFEF4444);        // Red
  static const Color logTimestamp = Color(0xFF4A6A88);    // Muted

  // ─── Testing ───
  static const Color testPassed = Color(0xFF22C55E);
  static const Color testFailed = Color(0xFFEF4444);
  static const Color testRunning = Color(0xFF3B9FE8);     // Logo blue
  static const Color testSkipped = Color(0xFF5B7A99);

  // ─── Legacy aliases (backward compat) ───
  static const Color muted = textMuted;
  static const Color surface = bgElevated;
}
