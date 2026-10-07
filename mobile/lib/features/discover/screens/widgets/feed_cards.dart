import 'package:flutter/material.dart';
import '../../../../core/theme/cartok_colors.dart';
import '../../models/cartok_feed_item.dart';

class _FeedCardShell extends StatelessWidget {
  const _FeedCardShell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: iconColor),
                  const SizedBox(width: 6),
                  Text(
                    label.toUpperCase(),
                    style: textTheme.labelSmall?.copyWith(color: iconColor, letterSpacing: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class FeedVehicleCard extends StatelessWidget {
  const FeedVehicleCard({super.key, required this.vehicle, required this.onTap});

  final CartokFeedVehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _FeedCardShell(
      icon: Icons.directions_car_filled_rounded,
      iconColor: CartokColors.redline,
      label: vehicle.garageName,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Text(vehicle.title, style: textTheme.titleMedium)),
          const Icon(Icons.favorite_rounded, size: 14, color: CartokColors.textTertiary),
          const SizedBox(width: 4),
          Text('${vehicle.likeCount}', style: textTheme.bodyMedium),
          const SizedBox(width: 12),
          const Icon(Icons.chat_bubble_rounded, size: 14, color: CartokColors.textTertiary),
          const SizedBox(width: 4),
          Text('${vehicle.commentCount}', style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class FeedThreadCard extends StatelessWidget {
  const FeedThreadCard({super.key, required this.thread, required this.onTap});

  final CartokFeedThread thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _FeedCardShell(
      icon: Icons.forum_rounded,
      iconColor: CartokColors.telemetry,
      label: 'Forum · ${thread.authorDisplayName}',
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(thread.title, style: textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: CartokColors.textTertiary),
          const SizedBox(width: 4),
          Text('${thread.postCount}', style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class FeedEventCard extends StatelessWidget {
  const FeedEventCard({super.key, required this.event, required this.onTap});

  final CartokFeedEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _FeedCardShell(
      icon: Icons.event_rounded,
      iconColor: CartokColors.verified,
      label: event.locationName,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Text(event.title, style: textTheme.titleMedium)),
          const Icon(Icons.people_alt_rounded, size: 14, color: CartokColors.textTertiary),
          const SizedBox(width: 4),
          Text('${event.rsvpCount} going', style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
