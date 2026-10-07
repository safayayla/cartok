import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../../../core/utils/share_helper.dart';
import '../providers/thread_detail_provider.dart';
import 'widgets/post_card.dart';

class ThreadDetailScreen extends ConsumerStatefulWidget {
  const ThreadDetailScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends ConsumerState<ThreadDetailScreen> {
  final _replyController = TextEditingController();
  bool _sendingReply = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final content = _replyController.text.trim();
    if (content.isEmpty) return;

    setState(() => _sendingReply = true);
    try {
      await ref.read(threadDetailProvider(widget.threadId).notifier).reply(content: content);
      _replyController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  Future<void> _handleVote(String postId, int value) async {
    try {
      await ref.read(threadDetailProvider(widget.threadId).notifier).vote(postId, value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vote failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(threadDetailProvider(widget.threadId));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(state.detail?.thread.title ?? 'Thread', overflow: TextOverflow.ellipsis),
        actions: [
          if (state.detail != null)
            IconButton(
              icon: Icon(
                state.detail!.thread.isBookmarkedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: state.detail!.thread.isBookmarkedByMe ? CartokColors.telemetry : null,
              ),
              tooltip: state.detail!.thread.isBookmarkedByMe ? 'Remove bookmark' : 'Bookmark',
              onPressed: () async {
                try {
                  await ref.read(threadDetailProvider(widget.threadId).notifier).toggleBookmark();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bookmark failed: $e')));
                  }
                }
              },
            ),
          if (state.detail != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: () => shareText(
                text: 'Check out this thread on Cartok: "${state.detail!.thread.title}"',
                subject: state.detail!.thread.title,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody(state, textTheme)),
            if (state.detail != null && !state.detail!.thread.isLocked) _buildComposer(),
            if (state.detail?.thread.isLocked == true)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: CartokColors.surfaceElevated,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 16, color: CartokColors.textTertiary),
                    const SizedBox(width: 8),
                    Text('This thread is locked', style: textTheme.bodyMedium),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThreadDetailState state, TextTheme textTheme) {
    if (state.isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 80,
              decoration: BoxDecoration(color: CartokColors.surface, borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      );
    }

    if (state.error != null) {
      return CartokErrorState(
        message: state.error.toString(),
        onRetry: () => ref.read(threadDetailProvider(widget.threadId).notifier).load(),
      );
    }

    final posts = state.detail?.posts ?? [];

    return RefreshIndicator(
      color: CartokColors.redline,
      backgroundColor: CartokColors.surfaceElevated,
      onRefresh: () => ref.read(threadDetailProvider(widget.threadId).notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          return PostCard(
            post: post,
            isReply: post.parentId != null,
            onUpvote: () => _handleVote(post.id, 1),
            onDownvote: () => _handleVote(post.id, -1),
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 24),
      decoration: const BoxDecoration(
        color: CartokColors.surface,
        border: Border(top: BorderSide(color: CartokColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              style: Theme.of(context).textTheme.bodyLarge,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Write a reply...'),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: _sendingReply ? null : _sendReply,
            style: IconButton.styleFrom(backgroundColor: CartokColors.redline),
            icon: _sendingReply
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CartokColors.textOnAccent),
                  )
                : const Icon(Icons.arrow_upward_rounded, color: CartokColors.textOnAccent),
          ),
        ],
      ),
    );
  }
}
