import 'package:flutter/material.dart';
import '../../../../core/theme/cartok_colors.dart';
import '../../../../core/theme/cartok_typography.dart';
import '../../models/cartok_vehicle.dart';

class VehicleCard extends StatelessWidget {
  const VehicleCard({super.key, required this.vehicle, this.onTap});

  final CartokVehicle vehicle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isVerified = vehicle.verificationStatus == 'VERIFIED';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: CartokColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CartokColors.borderSubtle),
                ),
                child: const Icon(Icons.directions_car_filled_rounded, color: CartokColors.telemetry, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            vehicle.title,
                            style: textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, size: 16, color: CartokColors.verified),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(vehicle.subtitle, style: textTheme.bodyMedium),
                    if (vehicle.odometer != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${vehicle.odometer} ${vehicle.odometerUnit}',
                        style: CartokTypography.telemetry(size: 12, color: CartokColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: CartokColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
