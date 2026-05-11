import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Suklu Design System — Color Tokens
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppColors {
  // ── Brand (Emerald modernisé) ───────────────────────
  static const Color primary      = Color(0xFF0F7A56);
  static const Color primaryLight = Color(0xFF10B981);
  static const Color primaryDark  = Color(0xFF065F46);

  // ── Secondaire (Amber chaud) ────────────────────────
  static const Color secondary     = Color(0xFFFBBF24);
  static const Color secondaryDark = Color(0xFFF59E0B);

  // ── Sémantique ──────────────────────────────────────
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error   = Color(0xFFDC2626);
  static const Color info    = Color(0xFF6366F1);

  // ── Neutres ─────────────────────────────────────────
  static const Color grey50  = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey900 = Color(0xFF111827);

  // ── Surfaces ─────────────────────────────────────────
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color background  = Color(0xFFF9FAFB);

  // ── Accents rôles ────────────────────────────────────
  static const Color studentAccent = Color(0xFF10B981); // Emerald
  static const Color tutorAccent   = Color(0xFF6366F1); // Indigo
  static const Color parentAccent  = Color(0xFFFBBF24); // Amber
  static const Color staffAccent   = Color(0xFFF97316); // Coral
  static const Color adminAccent   = Color(0xFFEF4444); // Red

  // ── Backgrounds tintés (pour icônes de rôle) ─────────
  static const Color studentAccentBg = Color(0xFFD1FAE5);
  static const Color tutorAccentBg   = Color(0xFFEDE9FE);
  static const Color parentAccentBg  = Color(0xFFFEF3C7);
  static const Color staffAccentBg   = Color(0xFFFFEDD5);
}
