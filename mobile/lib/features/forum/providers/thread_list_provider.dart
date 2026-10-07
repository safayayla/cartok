import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cartok_forum_thread.dart';
import '../repository/forum_repository.dart';
import 'forum_providers.dart';

class ThreadListState {
  const ThreadListState({
    this.items = const [],
    this.nextCursor,
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.error,
  });

  final List<CartokForumThread> items;
  final String? nextCursor;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final Object? error;

  bool get hasMore => nextCursor != null;

  ThreadListState copyWith({
    List<CartokForumThread>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
  }) =>
      ThreadListState(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        isInitialLoading: isInitialLoading ?? this.isInitialLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        error: clearError ? null : (error ?? this.error),
      );
}

class ThreadListNotifier extends StateNotifier<ThreadListState> {
  ThreadListNotifier(this._repository, this._categoryId) : super(const ThreadListState()) {
    _loadInitial();
  }

  final ForumRepository _repository;
  final String _categoryId;

  Future<void> _loadInitial() async {
    state = state.copyWith(isInitialLoading: true, clearError: true);
    try {
      final page = await _repository.listThreads(_categoryId);
      state = state.copyWith(items: page.items, nextCursor: page.nextCursor, clearCursor: page.nextCursor == null, isInitialLoading: false);
    } catch (e) {
      state = state.copyWith(isInitialLoading: false, error: e);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final page = await _repository.listThreads(_categoryId);
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isRefreshing: false,
      );
    } catch (e) {
      // Pull-to-refresh failing shouldn't nuke an already-loaded list — keep
      // showing what we have and let the refresh indicator just stop.
      state = state.copyWith(isRefreshing: false);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isInitialLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repository.listThreads(_categoryId, cursor: state.nextCursor);
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      );
    } catch (e) {
      // Load-more failing shouldn't disturb the existing list either — just
      // stop the spinner so the user can retry by scrolling again.
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Called after successfully creating a thread so it appears at the top
  /// immediately, without a full re-fetch.
  void prepend(CartokForumThread thread) {
    state = state.copyWith(items: [thread, ...state.items]);
  }
}

final threadListProvider =
    StateNotifierProvider.family<ThreadListNotifier, ThreadListState, String>((ref, categoryId) {
  return ThreadListNotifier(ref.watch(forumRepositoryProvider), categoryId);
});
