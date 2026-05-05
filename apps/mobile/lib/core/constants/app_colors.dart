import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Suklu Design System — Color Tokens
//
// Palette inspired by the vibrancy of Francophone West Africa while remaining
// accessible (WCAG AA on white backgrounds).
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF1A6B4A); // Deep forest green
  static const Color primaryLight = Color(0xFF2E9C6E);
  static const Color primaryDark  = Color(0xFF0E4830);

  static const Color secondary    = Color(0xFFF59E0B); // Warm amber / gold
  static const Color secondaryDark = Color(0xFFD97706);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success  = Color(0xFF16A34A);
  static const Color warning  = Color(0xFFF59E0B);
  static const Color error    = Color(0xFFDC2626);
  static const Color info     = Color(0xFF2563EB);

  // ── Neutral ────────────────────────────────────────────────────────────────
  static const Color grey50   = Color(0xFFF9FAFB);
  static const Color grey100  = Color(0xFFF3F4F6);
  static const Color grey200  = Color(0xFFE5E7EB);
  static const Color grey400  = Color(0xFF9CA3AF);
  static const Color grey600  = Color(0xFF4B5563);
  static const Color grey900  = Color(0xFF111827);

  // ── Surface ────────────────────────────────────────────────────────────────
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color surfaceDark  = Color(0xFF1F2937);
  static const Color background   = Color(0xFFF9FAFB);

  // ── Role-specific accent colors (used in dashboards) ──────────────────────
  static const Color studentAccent  = Color(0xFF6366F1); // Indigo
  static const Color tutorAccent    = Color(0xFF0EA5E9); // Sky blue
  static const Color parentAccent   = Color(0xFF8B5CF6); // Violet
  static const Color staffAccent    = Color(0xFFEC4899); // Pink
  static const Color adminAccent    = Color(0xFFEF4444); // Red
}
