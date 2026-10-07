import 'package:flutter/material.dart';
import '../../../../core/theme/cartok_colors.dart';
import '../../models/cartok_forum_thread.dart';

class ThreadListItem extends StatelessWidget {
  const ThreadListItem({super.key, required this.thread, this.onTap});

  final CartokForumThread thread;
  final VoidCallback? onTap;

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

    return Card(
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
                  if (thread.isPinned) ...[
                    const Icon(Icons.push_pin_rounded, size: 14, color: CartokColors.redline),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      thread.title,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (thread.isLocked) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.lock_outline_rounded, size: 16, color: CartokColors.textTertiary),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 14, color: CartokColors.textTertiary),
                  const SizedBox(width: 4),
                  Text('${thread.postCount}', style: textTheme.bodyMedium),
                  const SizedBox(width: 16),
                  Icon(Icons.visibility_outlined, size: 14, color: CartokColors.textTertiary),
                  const SizedBox(width: 4),
                  Text('${thread.viewCount}', style: textTheme.bodyMedium),
                  const Spacer(),
                  Text(_relativeTime(thread.updatedAt), style: textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
