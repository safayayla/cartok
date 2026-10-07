import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_empty_state.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../providers/listing_browse_provider.dart';
import 'widgets/listing_card.dart';

class MarketplaceBrowseScreen extends ConsumerStatefulWidget {
  const MarketplaceBrowseScreen({super.key});

  @override
  ConsumerState<MarketplaceBrowseScreen> createState() => _MarketplaceBrowseScreenState();
}

class _MarketplaceBrowseScreenState extends ConsumerState<MarketplaceBrowseScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(listingBrowseProvider.notifier).loadMore();
    }
  }

  void _onSearchSubmitted(String value) {
    final current = ref.read(listingBrowseProvider).filters;
    ref.read(listingBrowseProvider.notifier).applyFilters(current.copyWith(search: value));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(listingBrowseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded),
            tooltip: 'Favorites',
            onPressed: () => context.push('/marketplace/favorites'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/marketplace/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Sell'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              style: Theme.of(context).textTheme.bodyLarge,
              onSubmitted: _onSearchSubmitted,
              decoration: InputDecoration(
                hintText: 'Search parts, cars, wheels...',
                prefixIcon: const Icon(Icons.search_rounded, color: CartokColors.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchSubmitted('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: CartokColors.redline,
              backgroundColor: CartokColors.surfaceElevated,
              onRefresh: () => ref.read(listingBrowseProvider.notifier).refresh(),
              child: _buildBody(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ListingBrowseState state) {
    if (state.isInitialLoading) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(color: CartokColors.surface, borderRadius: BorderRadius.circular(16)),
        ),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: CartokErrorState(
              message: state.error.toString(),
              onRetry: () => ref.read(listingBrowseProvider.notifier).refresh(),
            ),
          ),
        ],
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: CartokEmptyState(
              icon: Icons.storefront_outlined,
              title: 'No listings found',
              message: state.filters.search != null && state.filters.search!.isNotEmpty
                  ? 'Nothing matched your search — try a different term.'
                  : 'Be the first to list something for sale.',
              actionLabel: 'Create a listing',
              onAction: () => context.push('/marketplace/new'),
            ),
          ),
        ],
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: CartokColors.telemetry),
            ),
          );
        }
        final listing = state.items[index];
        return ListingCard(listing: listing, onTap: () => context.push('/marketplace/${listing.id}'));
      },
    );
  }
}
