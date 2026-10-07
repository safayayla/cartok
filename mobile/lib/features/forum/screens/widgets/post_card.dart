import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/cartok_colors.dart';
import '../../models/cartok_forum_post.dart';
import 'vote_buttons.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.isReply,
    required this.onUpvote,
    required this.onDownvote,
  });

  final CartokForumPost post;
  final bool isReply;
  final VoidCallback onUpvote;
  final VoidCallback onDownvote;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.only(left: isReply ? 32 : 0, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReply ? CartokColors.surfaceElevated : CartokColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CartokColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VoteButtons(
            score: post.score,
            myVote: post.myVote,
            onUpvote: onUpvote,
            onDownvote: onDownvote,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: CartokColors.surfaceSunken,
                      backgroundImage:
                          post.author.avatarUrl != null ? CachedNetworkImageProvider(post.author.avatarUrl!) : null,
                      child: post.author.avatarUrl == null
                          ? Text(
                              post.author.displayName.isNotEmpty ? post.author.displayName[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 10, color: CartokColors.textSecondary),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(post.author.displayName, style: textTheme.labelLarge),
                    if (post.editedAt != null) ...[
                      const SizedBox(width: 6),
                      Text('(edited)', style: textTheme.labelSmall),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  post.content,
                  style: post.isDeleted
                      ? textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)
                      : textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
