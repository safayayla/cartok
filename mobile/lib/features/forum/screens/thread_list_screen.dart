import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_empty_state.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../providers/thread_list_provider.dart';
import 'widgets/thread_list_item.dart';
import 'create_thread_sheet.dart';

class ThreadListScreen extends ConsumerStatefulWidget {
  const ThreadListScreen({super.key, required this.categoryId, required this.categoryName});

  final String categoryId;
  final String categoryName;

  @override
  ConsumerState<ThreadListScreen> createState() => _ThreadListScreenState();
}

class _ThreadListScreenState extends ConsumerState<ThreadListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Trigger the next page a little before hitting the literal bottom, so
    // the next batch is already loading by the time the user gets there.
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(threadListProvider(widget.categoryId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(threadListProvider(widget.categoryId));

    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createThread(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New thread'),
      ),
      body: RefreshIndicator(
        color: CartokColors.redline,
        backgroundColor: CartokColors.surfaceElevated,
        onRefresh: () => ref.read(threadListProvider(widget.categoryId).notifier).refresh(),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(ThreadListState state) {
    if (state.isInitialLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          6,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 96,
              decoration: BoxDecoration(color: CartokColors.surface, borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: CartokErrorState(
              message: state.error.toString(),
              onRetry: () => ref.read(threadListProvider(widget.categoryId).notifier).refresh(),
            ),
          ),
        ],
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: CartokEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No threads yet',
              message: 'Be the first to start a conversation here.',
              actionLabel: 'Start a thread',
              onAction: () => _createThread(context),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: CartokColors.telemetry),
              ),
            ),
          );
        }
        final thread = state.items[index];
        return ThreadListItem(
          thread: thread,
          onTap: () => context.push('/forum/thread/${thread.id}'),
        );
      },
    );
  }

  Future<void> _createThread(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CartokColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CreateThreadSheet(categoryId: widget.categoryId),
    );
  }
}
