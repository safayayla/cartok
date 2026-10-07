import 'package:flutter/material.dart';

/// Cartok color tokens.
///
/// Design direction: an instrument-cluster read at night — asphalt-blue
/// surfaces (not flat black), a redline-orange primary accent for actions
/// that matter (the one thing your eye should catch, like a tachometer
/// needle crossing into the red), and a cool telemetry-cyan for data,
/// verification, and "live" states. Everything else stays quiet so those
/// two accents keep their meaning instead of competing with it.
class CartokColors {
  CartokColors._();

  // Surfaces — graphite with a cool blue undertone, never flat #000000.
  static const Color background = Color(0xFF12141A);
  static const Color surface = Color(0xFF1B1F27);
  static const Color surfaceElevated = Color(0xFF232833);
  static const Color surfaceSunken = Color(0xFF0D0F14);
  static const Color borderSubtle = Color(0xFF2E3440);
  static const Color borderStrong = Color(0xFF3C4453);

  // Text
  static const Color textPrimary = Color(0xFFF5F6F8);
  static const Color textSecondary = Color(0xFF9AA3AF);
  static const Color textTertiary = Color(0xFF6B7280);
  static const Color textOnAccent = Color(0xFF12141A);

  // Signature accents
  static const Color redline = Color(0xFFFF5A36); // primary CTA / redline
  static const Color redlineDim = Color(0xFF7A2E1D);
  static const Color telemetry = Color(0xFF4FD1E8); // data / verification / live
  static const Color telemetryDim = Color(0xFF1F5561);

  // Status
  static const Color verified = Color(0xFF34D399);
  static const Color pending = Color(0xFFF2B84B);
  static const Color danger = Color(0xFFF2495C);

  // Gradients used sparingly for the signature gauge-arc element.
  static const List<Color> redlineArc = [Color(0xFFFFD166), Color(0xFFFF5A36)];
  static const List<Color> telemetryArc = [Color(0xFF4FD1E8), Color(0xFF2E7DFF)];
}
