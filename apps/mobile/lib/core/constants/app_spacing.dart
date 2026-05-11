import 'package:flutter/material.dart';

// 4-pt grid system — consistent with Material 3 guidelines
abstract final class AppSpacing {
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;

  // Page-level padding
  static const EdgeInsets pagePadding = EdgeInsets.all(md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);

  // Border radii
  static const double radiusSm   = 10.0;
  static const double radiusMd   = 14.0;
  static const double radiusLg   = 16.0;
  static const double radiusXl   = 20.0;
  static const double radiusFull = 999.0;

  // Common gaps
  static const SizedBox gapXs  = SizedBox(height: xs,  width: xs);
  static const SizedBox gapSm  = SizedBox(height: sm,  width: sm);
  static const SizedBox gapMd  = SizedBox(height: md,  width: md);
  static const SizedBox gapLg  = SizedBox(height: lg,  width: lg);
  static const SizedBox gapXl  = SizedBox(height: xl,  width: xl);
}
