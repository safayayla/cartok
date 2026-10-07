import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/cartok_colors.dart';

class VehicleCardSkeleton extends StatelessWidget {
  const VehicleCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: CartokColors.surface,
      highlightColor: CartokColors.surfaceElevated,
      child: Container(
        height: 88,
        decoration: BoxDecoration(
          color: CartokColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
