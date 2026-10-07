import 'package:flutter/material.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_gauge_arc.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CartokColors.background,
      body: Center(
        child: CartokGaugeArc(
          progress: null,
          size: 88,
          strokeWidth: 6,
          center: const Icon(Icons.speed_rounded, color: CartokColors.redline, size: 34),
        ),
      ),
    );
  }
}
