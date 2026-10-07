import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_dependencies_provider.dart';
import '../../garage/models/cartok_garage.dart';
import '../../marketplace/models/cartok_listing.dart';
import '../../marketplace/providers/marketplace_providers.dart';
import '../../marketplace/repository/marketplace_repository.dart';
import '../../profile/models/cartok_public_profile.dart';
import '../repository/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(apiClientProvider));
});

class SearchState {
  const SearchState({
    this.query = '',
    this.garages = const [],
    this.users = const [],
    this.listings = const [],
    this.isLoading = false,
    this.error,
  });

  final String query;
  final List<CartokGarage> garages;
  final List<CartokFollowUser> users;
  final List<CartokListing> listings;
  final bool isLoading;
  final Object? error;

  bool get hasSearched => query.trim().length >= 2;
  bool get isEmpty => garages.isEmpty && users.isEmpty && listings.isEmpty;

  SearchState copyWith({
    String? query,
    List<CartokGarage>? garages,
    List<CartokFollowUser>? users,
    List<CartokListing>? listings,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) =>
      SearchState(
        query: query ?? this.query,
        garages: garages ?? this.garages,
        users: users ?? this.users,
        listings: listings ?? this.listings,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._searchRepository, this._marketplaceRepository) : super(const SearchState());

  final SearchRepository _searchRepository;
  final MarketplaceRepository _marketplaceRepository;
  Timer? _debounce;

  void onQueryChanged(String query) {
    state = state.copyWith(query: query);
    _debounce?.cancel();

    if (query.trim().length < 2) {
      state = state.copyWith(garages: [], users: [], listings: [], isLoading: false, clearError: true);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(query.trim()));
  }

  Future<void> _runSearch(String query) async {
    final requestQuery = query;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait<Object>([
        _searchRepository.searchGarages(query),
        _searchRepository.searchUsers(query),
        _marketplaceRepository.list(search: query),
      ]);

      if (state.query.trim() != requestQuery) return;

      state = state.copyWith(
        garages: results[0] as List<CartokGarage>,
        users: results[1] as List<CartokFollowUser>,
        listings: (results[2] as ListingPage).items,
        isLoading: false,
      );
    } catch (e) {
      if (state.query.trim() != requestQuery) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchProvider = StateNotifierProvider.autoDispose<SearchNotifier, SearchState>((ref) {
  return SearchNotifier(ref.watch(searchRepositoryProvider), ref.watch(marketplaceRepositoryProvider));
});
