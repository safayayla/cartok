import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cartok_notification.dart';
import '../repository/notifications_repository.dart';
import 'notifications_providers.dart';

class NotificationListState {
  const NotificationListState({
    this.items = const [],
    this.nextCursor,
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.error,
  });

  final List<CartokNotification> items;
  final String? nextCursor;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final Object? error;

  bool get hasMore => nextCursor != null;

  NotificationListState copyWith({
    List<CartokNotification>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
  }) =>
      NotificationListState(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        isInitialLoading: isInitialLoading ?? this.isInitialLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        error: clearError ? null : (error ?? this.error),
      );
}

class NotificationListNotifier extends StateNotifier<NotificationListState> {
  NotificationListNotifier(this._repository, this._ref) : super(const NotificationListState()) {
    _loadInitial();
  }

  final NotificationsRepository _repository;
  final Ref _ref;

  Future<void> _loadInitial() async {
    state = state.copyWith(isInitialLoading: true, clearError: true);
    try {
      final page = await _repository.list();
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isInitialLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isInitialLoading: false, error: e);
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final page = await _repository.list();
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isRefreshing: false,
      );
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      state = state.copyWith(isRefreshing: false);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isInitialLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repository.list(cursor: state.nextCursor);
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> markRead(String notificationId) async {
    final index = state.items.indexWhere((n) => n.id == notificationId);
    if (index == -1 || state.items[index].isRead) return;

    // Optimistic: flip the row immediately, revert only if the call fails.
    final updated = [...state.items];
    final original = updated[index];
    updated[index] = original.copyWith(isRead: true);
    state = state.copyWith(items: updated);

    try {
      await _repository.markRead(notificationId);
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      final reverted = [...state.items];
      reverted[index] = original;
      state = state.copyWith(items: reverted);
    }
  }

  Future<void> markAllRead() async {
    final original = state.items;
    state = state.copyWith(items: [for (final n in original) n.copyWith(isRead: true)]);
    try {
      await _repository.markAllRead();
      _ref.invalidate(unreadNotificationCountProvider);
    } catch (e) {
      state = state.copyWith(items: original);
    }
  }
}

final notificationListProvider = StateNotifierProvider<NotificationListNotifier, NotificationListState>((ref) {
  return NotificationListNotifier(ref.watch(notificationsRepositoryProvider), ref);
});
