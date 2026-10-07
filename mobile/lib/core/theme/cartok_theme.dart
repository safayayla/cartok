import 'package:flutter/material.dart';
import 'cartok_colors.dart';
import 'cartok_typography.dart';

class CartokTheme {
  CartokTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: CartokColors.background,
      colorScheme: const ColorScheme.dark(
        primary: CartokColors.redline,
        onPrimary: CartokColors.textOnAccent,
        secondary: CartokColors.telemetry,
        onSecondary: CartokColors.textOnAccent,
        surface: CartokColors.surface,
        onSurface: CartokColors.textPrimary,
        error: CartokColors.danger,
        onError: CartokColors.textPrimary,
      ),
      textTheme: CartokTypography.textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: CartokColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: CartokTypography.textTheme.headlineSmall,
        iconTheme: const IconThemeData(color: CartokColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: CartokColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CartokColors.borderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CartokColors.redline,
          foregroundColor: CartokColors.textOnAccent,
          disabledBackgroundColor: CartokColors.redlineDim,
          disabledForegroundColor: CartokColors.textTertiary,
          minimumSize: const Size.fromHeight(52),
          textStyle: CartokTypography.textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CartokColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: CartokColors.borderStrong),
          textStyle: CartokTypography.textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CartokColors.telemetry,
          textStyle: CartokTypography.textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CartokColors.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CartokColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CartokColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CartokColors.telemetry, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: CartokColors.danger),
        ),
        labelStyle: const TextStyle(color: CartokColors.textSecondary),
        hintStyle: const TextStyle(color: CartokColors.textTertiary),
      ),
      dividerTheme: const DividerThemeData(color: CartokColors.borderSubtle, thickness: 1, space: 1),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: CartokColors.surface,
        selectedItemColor: CartokColors.redline,
        unselectedItemColor: CartokColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CartokColors.surfaceElevated,
        contentTextStyle: CartokTypography.textTheme.bodyLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
