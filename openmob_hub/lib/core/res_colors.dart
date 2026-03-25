import 'package:flutter/material.dart';

class ResColors {
  ResColors._();

  // ─── Base palette (developer dark theme) ───
  static const Color bg = Color(0xFF0F172A);          // Slate 900 — main background
  static const Color bgElevated = Color(0xFF1E293B);   // Slate 800 — cards, elevated surfaces
  static const Color bgSurface = Color(0xFF334155);     // Slate 700 — input fields, hover
  static const Color border = Color(0xFF475569);        // Slate 600 — borders, dividers
  static const Color borderSubtle = Color(0xFF334155);  // Slate 700 — subtle borders

  // ─── Text ───
  static const Color textPrimary = Color(0xFFF8FAFC);   // Slate 50 — headings, primary text
  static const Color textSecondary = Color(0xFF94A3B8);  // Slate 400 — secondary, descriptions
  static const Color textMuted = Color(0xFF64748B);      // Slate 500 — hints, timestamps
  static const Color textOnAccent = Color(0xFFFFFFFF);   // White — text on colored buttons

  // ─── Accent (CTA green) ───
  static const Color accent = Color(0xFF22C55E);         // Green 500 — primary action
  static const Color accentHover = Color(0xFF16A34A);    // Green 600 — hover state
  static const Color accentSoft = Color(0x1A22C55E);     // Green 500 @ 10% — soft bg

  // ─── Status ───
  static const Color connected = Color(0xFF22C55E);      // Green 500
  static const Color running = Color(0xFF22C55E);        // Green 500
  static const Color warning = Color(0xFFF59E0B);        // Amber 500
  static const Color error = Color(0xFFEF4444);          // Red 500
  static const Color stopped = Color(0xFF64748B);        // Slate 500
  static const Color offline = Color(0xFFEF4444);        // Red 500
  static const Color bridged = Color(0xFF3B82F6);        // Blue 500

  // ─── Connection types ───
  static const Color usb = Color(0xFF3B82F6);            // Blue 500
  static const Color wifi = Color(0xFF22C55E);           // Green 500
  static const Color emulator = Color(0xFFF59E0B);       // Amber 500

  // ─── Sidebar ───
  static const Color sidebar = Color(0xFF0B1120);        // Deeper than bg
  static const Color sidebarActive = Color(0xFF1E293B);  // Elevated on active
  static const Color sidebarIcon = Color(0xFF64748B);    // Muted icons
  static const Color sidebarIconActive = Color(0xFF22C55E); // Green on active

  // ─── Cards ───
  static const Color cardBg = Color(0xFF1E293B);         // Slate 800
  static const Color cardBorder = Color(0xFF334155);     // Slate 700
  static const Color cardHover = Color(0xFF263548);      // Slightly lighter on hover

  // ─── Log viewer ───
  static const Color logBg = Color(0xFF0B1120);          // Deep dark
  static const Color logText = Color(0xFFCBD5E1);        // Slate 300
  static const Color logWarning = Color(0xFFF59E0B);     // Amber
  static const Color logError = Color(0xFFEF4444);       // Red
  static const Color logTimestamp = Color(0xFF475569);    // Slate 600

  // ─── Testing ───
  static const Color testPassed = Color(0xFF22C55E);
  static const Color testFailed = Color(0xFFEF4444);
  static const Color testRunning = Color(0xFF3B82F6);
  static const Color testSkipped = Color(0xFF64748B);

  // ─── Legacy aliases ───
  static const Color muted = textMuted;
  static const Color surface = bgElevated;
}
