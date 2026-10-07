import 'package:flutter/material.dart';
import '../../../../core/theme/cartok_colors.dart';
import '../../models/cartok_notification.dart';

class NotificationListItem extends StatelessWidget {
  const NotificationListItem({super.key, required this.notification, required this.onTap});

  final CartokNotification notification;
  final VoidCallback onTap;

  static const _iconByType = <String, IconData>{
    'GARAGE_FOLLOW': Icons.garage_rounded,
    'THREAD_REPLY': Icons.chat_bubble_rounded,
    'POST_MENTION': Icons.alternate_email_rounded,
    'POST_VOTE': Icons.arrow_upward_rounded,
    'VEHICLE_VERIFIED': Icons.verified_rounded,
    'EVENT_RSVP': Icons.event_available_rounded,
    'EVENT_REMINDER': Icons.event_note_rounded,
    'EVENT_CANCELLED': Icons.event_busy_rounded,
    'SYSTEM': Icons.info_outline_rounded,
  };

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final icon = _iconByType[notification.type] ?? Icons.notifications_rounded;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: notification.isRead ? Colors.transparent : CartokColors.telemetryDim.withOpacity(0.12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CartokColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 19, color: CartokColors.telemetry),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notification.message, style: textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text(_relativeTime(notification.createdAt), style: textTheme.labelSmall),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(top: 4, left: 8),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: CartokColors.redline, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
