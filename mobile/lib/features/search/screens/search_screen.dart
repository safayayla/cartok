import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_empty_state.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../../marketplace/screens/widgets/listing_card.dart';
import '../providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final textTheme = Theme.of(context).textTheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _controller,
            autofocus: true,
            style: textTheme.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Search garages, people, parts...',
              border: InputBorder.none,
            ),
            onChanged: (value) => ref.read(searchProvider.notifier).onQueryChanged(value),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Garages${state.garages.isNotEmpty ? ' (${state.garages.length})' : ''}'),
              Tab(text: 'People${state.users.isNotEmpty ? ' (${state.users.length})' : ''}'),
              Tab(text: 'Marketplace${state.listings.isNotEmpty ? ' (${state.listings.length})' : ''}'),
            ],
          ),
        ),
        body: !state.hasSearched
            ? const CartokEmptyState(
                icon: Icons.search_rounded,
                title: 'Search Cartok',
                message: 'Find garages, people, and parts for sale.',
              )
            : state.isLoading
                ? const Center(child: CircularProgressIndicator(color: CartokColors.redline))
                : state.error != null
                    ? CartokErrorState(
                        message: state.error.toString(),
                        onRetry: () => ref.read(searchProvider.notifier).onQueryChanged(state.query),
                      )
                    : state.isEmpty
                        ? const CartokEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No results',
                            message: 'Try a different search term.',
                          )
                        : TabBarView(
                            children: [
                              _GarageResults(garages: state.garages),
                              _UserResults(users: state.users),
                              _ListingResults(listings: state.listings),
                            ],
                          ),
      ),
    );
  }
}

class _GarageResults extends StatelessWidget {
  const _GarageResults({required this.garages});
  final List garages;

  @override
  Widget build(BuildContext context) {
    if (garages.isEmpty) {
      return const CartokEmptyState(icon: Icons.garage_outlined, title: 'No garages found', message: '');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: garages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final garage = garages[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: CartokColors.surfaceElevated,
              backgroundImage: garage.coverUrl != null ? CachedNetworkImageProvider(garage.coverUrl!) : null,
              child: garage.coverUrl == null ? const Icon(Icons.garage_rounded, color: CartokColors.telemetry) : null,
            ),
            title: Text(garage.name),
            subtitle: Text('${garage.followerCount} followers'),
            onTap: () => context.push('/garage/detail/${garage.id}'),
          ),
        );
      },
    );
  }
}

class _UserResults extends StatelessWidget {
  const _UserResults({required this.users});
  final List users;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const CartokEmptyState(icon: Icons.person_outline_rounded, title: 'No people found', message: '');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: CartokColors.surfaceElevated,
            backgroundImage: user.avatarUrl != null ? CachedNetworkImageProvider(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?')
                : null,
          ),
          title: Text(user.displayName),
          subtitle: Text('@${user.username}'),
          onTap: () => context.push('/profile/${user.username}'),
        );
      },
    );
  }
}

class _ListingResults extends StatelessWidget {
  const _ListingResults({required this.listings});
  final List listings;

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      return const CartokEmptyState(icon: Icons.storefront_outlined, title: 'No listings found', message: '');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        final listing = listings[index];
        return ListingCard(listing: listing, onTap: () => context.push('/marketplace/${listing.id}'));
      },
    );
  }
}
