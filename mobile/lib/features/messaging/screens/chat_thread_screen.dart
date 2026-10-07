import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../../auth/providers/auth_notifier.dart';
import '../models/cartok_message.dart';
import '../providers/chat_thread_provider.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.conversationId, this.otherDisplayName});

  final String conversationId;
  final String? otherDisplayName;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // List is reversed (newest at the bottom, per ChatThreadState's own
    // doc comment), so "scrolled near the top of history" means close to
    // maxScrollExtent, not 0 — this is the inverse of the forum's
    // load-more trigger for exactly that reason.
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(chatThreadProvider(widget.conversationId).notifier).loadOlder();
    }
  }

  Future<void> _send() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    final currentUserId = ref.read(authNotifierProvider).user?.id;
    if (currentUserId == null) return;

    setState(() => _sending = true);
    _messageController.clear();
    try {
      await ref.read(chatThreadProvider(widget.conversationId).notifier).send(content, currentUserId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatThreadProvider(widget.conversationId));
    final currentUserId = ref.watch(authNotifierProvider.select((s) => s.user?.id));

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherDisplayName ?? 'Conversation')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody(state, currentUserId)),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ChatThreadState state, String? currentUserId) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: CartokColors.redline));
    }

    if (state.error != null) {
      return CartokErrorState(
        message: state.error.toString(),
        onRetry: () => ref.read(chatThreadProvider(widget.conversationId).notifier).load(),
      );
    }

    if (state.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No messages yet. Say hello!',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: state.messages.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: CartokColors.telemetry),
              ),
            ),
          );
        }
        final message = state.messages[index];
        final isMine = message.senderId == currentUserId;
        final isPending = state.pendingIds.contains(message.id);
        return _MessageBubble(message: message, isMine: isMine, isPending: isPending);
      },
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 20),
      decoration: const BoxDecoration(
        color: CartokColors.surface,
        border: Border(top: BorderSide(color: CartokColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: Theme.of(context).textTheme.bodyLarge,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Message...'),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(backgroundColor: CartokColors.redline),
            icon: const Icon(Icons.arrow_upward_rounded, color: CartokColors.textOnAccent),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine, required this.isPending});

  final CartokMessage message;
  final bool isMine;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? CartokColors.redline : CartokColors.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Opacity(
          opacity: isPending ? 0.6 : 1.0,
          child: Text(
            message.content,
            style: textTheme.bodyLarge?.copyWith(color: isMine ? CartokColors.textOnAccent : CartokColors.textPrimary),
          ),
        ),
      ),
    );
  }
}
