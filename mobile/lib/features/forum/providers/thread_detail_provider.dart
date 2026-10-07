import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cartok_forum_post.dart';
import '../repository/forum_repository.dart';
import 'forum_providers.dart';

class ThreadDetailState {
  const ThreadDetailState({this.detail, this.isLoading = true, this.error});

  final CartokForumThreadDetail? detail;
  final bool isLoading;
  final Object? error;

  ThreadDetailState copyWith({CartokForumThreadDetail? detail, bool? isLoading, Object? error, bool clearError = false}) =>
      ThreadDetailState(
        detail: detail ?? this.detail,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class ThreadDetailNotifier extends StateNotifier<ThreadDetailState> {
  ThreadDetailNotifier(this._repository, this._threadId) : super(const ThreadDetailState()) {
    load();
  }

  final ForumRepository _repository;
  final String _threadId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final detail = await _repository.getThread(_threadId);
      state = state.copyWith(detail: detail, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> reply({required String content, String? parentId}) async {
    final newPost = await _repository.createPost(_threadId, content: content, parentId: parentId);
    final detail = state.detail;
    if (detail == null) return;
    state = state.copyWith(detail: CartokForumThreadDetail(thread: detail.thread, posts: [...detail.posts, newPost]));
  }

  /// Optimistic, same reasoning as vote() below and toggleLike() on the
  /// vehicle detail provider: flips instantly, rolls back only on failure.
  Future<void> toggleBookmark() async {
    final detail = state.detail;
    if (detail == null) return;

    final wasBookmarked = detail.thread.isBookmarkedByMe;
    final optimisticThread = detail.thread.copyWith(isBookmarkedByMe: !wasBookmarked);
    state = state.copyWith(detail: CartokForumThreadDetail(thread: optimisticThread, posts: detail.posts));

    try {
      if (wasBookmarked) {
        await _repository.unbookmarkThread(_threadId);
      } else {
        await _repository.bookmarkThread(_threadId);
      }
    } catch (e) {
      state = state.copyWith(detail: detail);
      rethrow;
    }
  }

  /// Flips a post's vote optimistically: the score and button state update
  /// immediately, before the network call resolves. If the call fails, the
  /// change is rolled back and the caller (the UI) is responsible for
  /// surfacing that failure (e.g. a snackbar) — this method just restores
  /// correct state either way.
  Future<void> vote(String postId, int value) async {
    final detail = state.detail;
    if (detail == null) return;

    final index = detail.posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final original = detail.posts[index];

    final alreadyThisValue = original.myVote == value;
    final newValue = alreadyThisValue ? null : value;

    // Compute the score delta the same way the backend does: removing a
    // vote moves the score by the vote's old value; flipping moves it by
    // the difference; a fresh vote moves it by the new value outright.
    final delta = (newValue ?? 0) - (original.myVote ?? 0);
    final optimistic = original.copyWith(score: original.score + delta, myVote: newValue, clearMyVote: newValue == null);

    final optimisticPosts = [...detail.posts];
    optimisticPosts[index] = optimistic;
    state = state.copyWith(detail: CartokForumThreadDetail(thread: detail.thread, posts: optimisticPosts));

    try {
      if (newValue == null) {
        await _repository.removeVote(_threadId, postId);
      } else {
        await _repository.vote(_threadId, postId, newValue);
      }
    } catch (e) {
      // Roll back to the exact pre-vote state on failure.
      final revertedPosts = [...optimisticPosts];
      revertedPosts[index] = original;
      state = state.copyWith(detail: CartokForumThreadDetail(thread: detail.thread, posts: revertedPosts));
      rethrow;
    }
  }
}

final threadDetailProvider =
    StateNotifierProvider.family<ThreadDetailNotifier, ThreadDetailState, String>((ref, threadId) {
  return ThreadDetailNotifier(ref.watch(forumRepositoryProvider), threadId);
});
