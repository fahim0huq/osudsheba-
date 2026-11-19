import 'package:flutter/material.dart';

/// Colour palette.
///
/// Every colour used for text, icons or button fills meets WCAG AA contrast (4.5:1 or
/// better) against white, which matters for older eyes and for phones used outdoors.
/// The previous palette (e.g. #10B981 with white text, 2.5:1) did not.
class AppColors {
  // Primary Theme Colors (calm emerald healthcare style)
  static const Color primary = Color(0xFF047857);       // Emerald 700 — 5.5:1 with white
  static const Color primaryDark = Color(0xFF065F46);   // Emerald 800
  static const Color primaryLight = Color(0xFFECFDF5);  // Mint background
  static const Color accent = Color(0xFF1D4ED8);        // Blue 700
  static const Color softGreen = Color(0xFFD1FAE5);     // Soft green accent

  // System Colors
  static const Color background = Color(0xFFF9FAFB);    // Light gray
  static const Color surface = Colors.white;
  static const Color cardBg = Colors.white;

  // Feedback Colors (all usable as text or as a fill behind white text)
  static const Color success = Color(0xFF15803D);       // Taken — 5.0:1
  static const Color warning = Color(0xFFB45309);       // Snoozed / attention — 5.0:1
  static const Color error = Color(0xFFB91C1C);         // Missed / destructive — 6.5:1
  static const Color info = Color(0xFF1D4ED8);          // Info blue — 6.7:1

  // Text Colors
  static const Color textPrimary = Color(0xFF111827);   // 17:1
  static const Color textSecondary = Color(0xFF4B5563); // 7.6:1
  static const Color textLight = Colors.white;

  // Borders and Dividers
  static const Color border = Color(0xFFD1D5DB);
  static const Color shadow = Color(0x0A000000);
}
