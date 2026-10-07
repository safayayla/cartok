import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cartok_colors.dart';

/// Type system: Space Grotesk carries the app's personality on headings —
/// a geometric, slightly mechanical display face that reads like it belongs
/// on a dashboard, not a SaaS landing page. Inter handles body copy for
/// pure legibility. JetBrains Mono is reserved for telemetry-style data:
/// VIN, odometer, dyno figures, timestamps — anywhere a fixed-width readout
/// reinforces "this is a real measurement."
class CartokTypography {
  CartokTypography._();

  static TextTheme get textTheme => TextTheme(
        displayLarge: GoogleFonts.getFont('Space Grotesk',
          fontSize: 40,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.05,
          color: CartokColors.textPrimary,
        ),
        displayMedium: GoogleFonts.getFont('Space Grotesk',
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          height: 1.1,
          color: CartokColors.textPrimary,
        ),
        headlineMedium: GoogleFonts.getFont('Space Grotesk',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: CartokColors.textPrimary,
        ),
        headlineSmall: GoogleFonts.getFont('Space Grotesk',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: CartokColors.textPrimary,
        ),
        titleMedium: GoogleFonts.getFont('Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: CartokColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.getFont('Inter',
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: CartokColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.getFont('Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: CartokColors.textSecondary,
        ),
        labelLarge: GoogleFonts.getFont('Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: CartokColors.textPrimary,
        ),
        labelSmall: GoogleFonts.getFont('Inter',
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          color: CartokColors.textTertiary,
        ),
      );

  /// Fixed-width "telemetry readout" style — VIN strings, odometer figures,
  /// dyno numbers, timestamps. Never used for prose.
  static TextStyle telemetry({double size = 14, Color? color, FontWeight? weight}) =>
      GoogleFonts.getFont('JetBrains Mono',
        fontSize: size,
        fontWeight: weight ?? FontWeight.w500,
        letterSpacing: 0.2,
        color: color ?? CartokColors.textPrimary,
      );
}
