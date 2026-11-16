import 'package:flutter/material.dart';

/// Quick Basket Brand & Theme Colors
///
/// Fresh green + warm yellow palette from the approved redesign.
class AppColors {
  AppColors._();

  // Brand Primaries
  static const Color primary = Color(0xFF0C8340); // Fresh leaf green
  static const Color primaryDark = Color(0xFF064E2B); // Deep forest
  static const Color primaryDeep = Color(0xFF0A6B35); // Text-on-tint green
  static const Color primaryLight = Color(0xFFE3F4E6); // Soft green tint
  static const Color primaryTint = Color(0xFFF0F8F3); // Selected surfaces
  static const Color primaryAccent = Color(0xFF10B981);

  // Secondary & Accents
  static const Color secondary = Color(0xFFFF7A00); // Legacy orange (kept for compatibility)
  static const Color secondaryLight = Color(0xFFFFF3E0);
  static const Color accent = Color(0xFFFFC72C); // Brand yellow
  static const Color accentLight = Color(0xFFFFF6D6);
  static const Color accentBorder = Color(0xFFF5E2A0);
  static const Color accentInk = Color(0xFF7A5600);

  // Neutrals & Surfaces
  static const Color background = Color(0xFFF6F8F5);
  static const Color adminBackground = Color(0xFFF5F7F5);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF1F4F2);
  static const Color cardBackground = Colors.white;
  static const Color divider = Color(0xFFEEF2EF);
  static const Color border = Color(0xFFE7ECE8);
  static const Color borderStrong = Color(0xFFD5DDD8);

  // Text Colors
  static const Color textPrimary = Color(0xFF14201A);
  static const Color textBody = Color(0xFF3F4D45);
  static const Color textSecondary = Color(0xFF5B6B62);
  static const Color textMuted = Color(0xFF6B7A71);

  // Feedback Colors
  static const Color success = Color(0xFF0C8340);
  static const Color error = Color(0xFFB42318);
  static const Color errorLight = Color(0xFFFDE8E8);
  static const Color errorBorder = Color(0xFFF3C7C3);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B4FA0);
  static const Color infoLight = Color(0xFFE6ECFA);
  static const Color purple = Color(0xFF7C5FC9);
  static const Color indigo = Color(0xFF4A63C4);

  // Badges & Offers
  static const Color offerBadge = Color(0xFFFFC72C);
  static const Color discountGreen = Color(0xFF0A6B35);
}
