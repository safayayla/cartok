import 'package:flutter/material.dart';
import '../../../../core/theme/cartok_colors.dart';
import '../../../../core/theme/cartok_typography.dart';
import '../../models/cartok_event.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap});

  final CartokEvent event;
  final VoidCallback? onTap;

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day} · $hour12:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: CartokColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CartokColors.borderSubtle),
                ),
                child: const Icon(Icons.directions_car_filled_rounded, color: CartokColors.redline, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.typeLabel.toUpperCase(),
                      style: CartokTypography.telemetry(size: 11, color: CartokColors.telemetry, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(event.title, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Text(_formatDate(event.startTime), style: textTheme.bodyMedium),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: CartokColors.textTertiary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            event.locationName,
                            style: textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text('${event.goingCount}', style: textTheme.titleMedium),
                  Text('going', style: textTheme.labelSmall),
                  if (event.isFull) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CartokColors.danger.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('FULL', style: TextStyle(fontSize: 9, color: CartokColors.danger)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
