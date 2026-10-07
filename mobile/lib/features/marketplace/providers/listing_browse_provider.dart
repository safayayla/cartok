import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cartok_listing.dart';
import '../repository/marketplace_repository.dart';
import 'marketplace_providers.dart';

class ListingFilters {
  const ListingFilters({this.type, this.minPriceCents, this.maxPriceCents, this.search});

  final String? type;
  final int? minPriceCents;
  final int? maxPriceCents;
  final String? search;

  ListingFilters copyWith({
    String? type,
    bool clearType = false,
    int? minPriceCents,
    int? maxPriceCents,
    String? search,
  }) =>
      ListingFilters(
        type: clearType ? null : (type ?? this.type),
        minPriceCents: minPriceCents ?? this.minPriceCents,
        maxPriceCents: maxPriceCents ?? this.maxPriceCents,
        search: search ?? this.search,
      );
}

class ListingBrowseState {
  const ListingBrowseState({
    this.items = const [],
    this.nextCursor,
    this.isInitialLoading = true,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.error,
    this.filters = const ListingFilters(),
  });

  final List<CartokListing> items;
  final String? nextCursor;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool isRefreshing;
  final Object? error;
  final ListingFilters filters;

  bool get hasMore => nextCursor != null;

  ListingBrowseState copyWith({
    List<CartokListing>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? isInitialLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
    ListingFilters? filters,
  }) =>
      ListingBrowseState(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        isInitialLoading: isInitialLoading ?? this.isInitialLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        error: clearError ? null : (error ?? this.error),
        filters: filters ?? this.filters,
      );
}

class ListingBrowseNotifier extends StateNotifier<ListingBrowseState> {
  ListingBrowseNotifier(this._repository) : super(const ListingBrowseState()) {
    _load();
  }

  final MarketplaceRepository _repository;

  Future<void> _load() async {
    state = state.copyWith(isInitialLoading: true, clearError: true);
    try {
      final page = await _repository.list(
        type: state.filters.type,
        minPriceCents: state.filters.minPriceCents,
        maxPriceCents: state.filters.maxPriceCents,
        search: state.filters.search,
      );
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

  Future<void> applyFilters(ListingFilters filters) async {
    state = state.copyWith(filters: filters);
    await _load();
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final page = await _repository.list(
        type: state.filters.type,
        minPriceCents: state.filters.minPriceCents,
        maxPriceCents: state.filters.maxPriceCents,
        search: state.filters.search,
      );
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
      final page = await _repository.list(
        type: state.filters.type,
        minPriceCents: state.filters.minPriceCents,
        maxPriceCents: state.filters.maxPriceCents,
        search: state.filters.search,
        cursor: state.nextCursor,
      );
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

  void prepend(CartokListing listing) {
    state = state.copyWith(items: [listing, ...state.items]);
  }
}

final listingBrowseProvider = StateNotifierProvider<ListingBrowseNotifier, ListingBrowseState>((ref) {
  return ListingBrowseNotifier(ref.watch(marketplaceRepositoryProvider));
});
