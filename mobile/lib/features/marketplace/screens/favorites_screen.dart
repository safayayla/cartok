import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_empty_state.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../providers/marketplace_providers.dart';
import 'widgets/listing_card.dart';

final _favoritesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(marketplaceRepositoryProvider).favorites();
});

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(_favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: RefreshIndicator(
        color: CartokColors.redline,
        backgroundColor: CartokColors.surfaceElevated,
        onRefresh: () async => ref.invalidate(_favoritesProvider),
        child: favoritesAsync.when(
          loading: () => GridView.builder(
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
          ),
          error: (err, _) => ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: CartokErrorState(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(_favoritesProvider),
                ),
              ),
            ],
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const CartokEmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'No favorites yet',
                      message: 'Tap the heart on any listing to save it here.',
                    ),
                  ),
                ],
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemCount: page.items.length,
              itemBuilder: (context, index) {
                final listing = page.items[index];
                return ListingCard(listing: listing, onTap: () => context.push('/marketplace/${listing.id}'));
              },
            );
          },
        ),
      ),
    );
  }
}
