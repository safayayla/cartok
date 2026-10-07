import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_dependencies_provider.dart';
import '../models/cartok_event.dart';
import '../repository/events_repository.dart';

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref.watch(apiClientProvider));
});

class EventListState {
  const EventListState({
    this.items = const [],
    this.nextCursor,
    this.selectedType,
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.error,
  });

  final List<CartokEvent> items;
  final String? nextCursor;
  final String? selectedType; // null = all types
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final Object? error;

  bool get hasMore => nextCursor != null;

  EventListState copyWith({
    List<CartokEvent>? items,
    String? nextCursor,
    bool clearCursor = false,
    String? selectedType,
    bool clearType = false,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
  }) =>
      EventListState(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        selectedType: clearType ? null : (selectedType ?? this.selectedType),
        isInitialLoading: isInitialLoading ?? this.isInitialLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        error: clearError ? null : (error ?? this.error),
      );
}

class EventListNotifier extends StateNotifier<EventListState> {
  EventListNotifier(this._repository) : super(const EventListState()) {
    _load();
  }

  final EventsRepository _repository;

  Future<void> _load() async {
    state = state.copyWith(isInitialLoading: true, clearError: true);
    try {
      final page = await _repository.list(type: state.selectedType);
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

  Future<void> setType(String? type) async {
    state = state.copyWith(selectedType: type, clearType: type == null);
    await _load();
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final page = await _repository.list(type: state.selectedType);
      state = state.copyWith(
        items: page.items,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(isRefreshing: false);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isInitialLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repository.list(type: state.selectedType, cursor: state.nextCursor);
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

  void prepend(CartokEvent event) {
    state = state.copyWith(items: [event, ...state.items]);
  }
}

final eventListProvider = StateNotifierProvider<EventListNotifier, EventListState>((ref) {
  return EventListNotifier(ref.watch(eventsRepositoryProvider));
});
