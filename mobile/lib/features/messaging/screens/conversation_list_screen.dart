import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_empty_state.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../providers/conversation_list_provider.dart';

class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationListProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: RefreshIndicator(
        color: CartokColors.redline,
        backgroundColor: CartokColors.surfaceElevated,
        onRefresh: () => ref.read(conversationListProvider.notifier).load(),
        child: _buildBody(context, ref, state, textTheme),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, ConversationListState state, TextTheme textTheme) {
    if (state.isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 6,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: CartokColors.surface, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(color: CartokColors.surface, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.error != null) {
      return CartokErrorState(
        message: state.error.toString(),
        onRetry: () => ref.read(conversationListProvider.notifier).load(),
      );
    }

    if (state.items.isEmpty) {
      return const CartokEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'No messages yet',
        message: 'Message someone from their profile to start a conversation.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final convo = state.items[index];
        final other = convo.otherParticipant;
        final preview = convo.lastMessage?.content ?? 'Say hello!';

        return ListTile(
          onTap: () => context.push('/messages/${convo.conversationId}', extra: other?.displayName),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: CartokColors.surfaceElevated,
            backgroundImage: other?.avatarUrl != null ? CachedNetworkImageProvider(other!.avatarUrl!) : null,
            child: other?.avatarUrl == null
                ? Text(other?.displayName.isNotEmpty == true ? other!.displayName[0].toUpperCase() : '?')
                : null,
          ),
          title: Text(
            other?.displayName ?? 'Unknown user',
            style: convo.isUnread ? textTheme.titleMedium : textTheme.bodyLarge,
          ),
          subtitle: Text(
            preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: convo.isUnread
                ? textTheme.bodyMedium?.copyWith(color: CartokColors.textPrimary, fontWeight: FontWeight.w600)
                : textTheme.bodyMedium,
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_relativeTime(convo.updatedAt), style: textTheme.labelSmall),
              if (convo.isUnread) ...[
                const SizedBox(height: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: CartokColors.redline, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
