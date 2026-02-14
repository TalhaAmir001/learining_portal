// lib/utils/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Triadic Color Scheme - Blue, Purple, Teal
  static const Color primaryBlue = Color(0xFF2A4F6E); // Deep ocean blue
  static const Color secondaryPurple = Color(0xFF6B4E71); // Muted purple
  static const Color accentTeal = Color(0xFF4A919E); // Soft teal

  // Supporting colors
  static const Color backgroundLight = Color(0xFFF8FAFC); // Light background
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, secondaryPurple],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryPurple, accentTeal],
  );

  static const LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8FAFC), Color(0xFFEFF3F8)],
  );
}
