import 'package:flutter/material.dart';

/// OpenMob color palette
/// Dark slate base (industry standard for dev tools) with logo blue accent.
/// Green reserved for status only. Orange appears on high-priority CTAs.
class ResColors {
  ResColors._();

  // ─── Base palette (slate dark theme — proven for dev tools) ───
  static const Color bg = Color(0xFF0F172A);            // Slate 900 — main background
  static const Color bgElevated = Color(0xFF1E293B);     // Slate 800 — cards, elevated
  static const Color bgSurface = Color(0xFF334155);       // Slate 700 — inputs, hover
  static const Color border = Color(0xFF475569);          // Slate 600 — borders
  static const Color borderSubtle = Color(0xFF334155);    // Slate 700 — subtle borders

  // ─── Text ───
  static const Color textPrimary = Color(0xFFF8FAFC);    // Slate 50 — headings
  static const Color textSecondary = Color(0xFF94A3B8);   // Slate 400 — secondary
  static const Color textMuted = Color(0xFF64748B);       // Slate 500 — hints
  static const Color textOnAccent = Color(0xFFFFFFFF);    // White — on colored buttons

  // ─── Primary accent (logo blue — interactive elements) ───
  static const Color accent = Color(0xFF3B82F6);          // Blue 500 — primary interactive
  static const Color accentHover = Color(0xFF2563EB);     // Blue 600 — hover
  static const Color accentSoft = Color(0x1A3B82F6);     // Blue @ 10% — soft bg
  static const Color accentBright = Color(0xFF60A5FA);    // Blue 400 — highlights

  // ─── CTA (logo orange — high-priority actions only) ───
  static const Color cta = Color(0xFFF97316);             // Orange 500 — install, download
  static const Color ctaHover = Color(0xFFEA580C);        // Orange 600 — hover
  static const Color ctaSoft = Color(0x1AF97316);         // Orange @ 10%

  // ─── Status (green = success, standard UX convention) ───
  static const Color connected = Color(0xFF22C55E);       // Green 500
  static const Color running = Color(0xFF22C55E);         // Green 500
  static const Color warning = Color(0xFFF59E0B);         // Amber 500
  static const Color error = Color(0xFFEF4444);           // Red 500
  static const Color stopped = Color(0xFF64748B);         // Slate 500
  static const Color offline = Color(0xFFEF4444);         // Red 500
  static const Color bridged = Color(0xFF3B82F6);         // Blue 500

  // ─── Connection types ───
  static const Color usb = Color(0xFF3B82F6);             // Blue 500
  static const Color wifi = Color(0xFF22C55E);            // Green 500
  static const Color emulator = Color(0xFFF59E0B);        // Amber 500

  // ─── Sidebar ───
  static const Color sidebar = Color(0xFF0B1120);         // Deeper than bg
  static const Color sidebarActive = Color(0xFF1E293B);   // Elevated on active
  static const Color sidebarIcon = Color(0xFF64748B);     // Muted icons
  static const Color sidebarIconActive = Color(0xFF3B82F6); // Blue on active

  // ─── Cards ───
  static const Color cardBg = Color(0xFF1E293B);          // Slate 800
  static const Color cardBorder = Color(0xFF334155);      // Slate 700
  static const Color cardHover = Color(0xFF263548);       // Slightly lighter

  // ─── Log viewer ───
  static const Color logBg = Color(0xFF0B1120);           // Deep dark
  static const Color logText = Color(0xFFCBD5E1);         // Slate 300
  static const Color logWarning = Color(0xFFF59E0B);      // Amber
  static const Color logError = Color(0xFFEF4444);        // Red
  static const Color logTimestamp = Color(0xFF475569);     // Slate 600

  // ─── Testing ───
  static const Color testPassed = Color(0xFF22C55E);
  static const Color testFailed = Color(0xFFEF4444);
  static const Color testRunning = Color(0xFF3B82F6);
  static const Color testSkipped = Color(0xFF64748B);

  // ─── Legacy aliases ───
  static const Color muted = textMuted;
  static const Color surface = bgElevated;
  // Backward compat — old code using these still works
  static const Color primary = accent;
  static const Color primaryDark = accentHover;
  static const Color primarySoft = accentSoft;
  static const Color primaryLight = accentBright;
}
