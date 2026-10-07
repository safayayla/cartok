import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../../../core/utils/share_helper.dart';
import '../../auth/providers/auth_notifier.dart';
import '../models/cartok_listing.dart';
import '../providers/marketplace_providers.dart';
import '../providers/listing_browse_provider.dart';

final _listingDetailProvider = FutureProvider.family<CartokListing, String>((ref, listingId) {
  return ref.watch(marketplaceRepositoryProvider).getById(listingId);
});

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  // Defaults to false because GET /marketplace/:id doesn't return whether
  // the current viewer has already favorited this listing (the backend
  // response has no such field). This is a real, known gap — the favorite
  // button always starts unfilled even if the user favorited it earlier in
  // a previous session, until the backend adds that field to the response.
  bool _isFavorited = false;
  bool _togglingFavorite = false;

  Future<void> _toggleFavorite() async {
    setState(() => _togglingFavorite = true);
    final repo = ref.read(marketplaceRepositoryProvider);
    try {
      if (_isFavorited) {
        await repo.unfavorite(widget.listingId);
      } else {
        await repo.favorite(widget.listingId);
      }
      setState(() => _isFavorited = !_isFavorited);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _togglingFavorite = false);
    }
  }

  Future<void> _markSold() async {
    try {
      await ref.read(marketplaceRepositoryProvider).updateStatus(widget.listingId, 'SOLD');
      ref.invalidate(_listingDetailProvider(widget.listingId));
      ref.invalidate(listingBrowseProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(_listingDetailProvider(widget.listingId));
    final currentUserId = ref.watch(authNotifierProvider.select((s) => s.user?.id));
    final textTheme = Theme.of(context).textTheme;

    return listingAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: CartokColors.redline))),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: CartokErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(_listingDetailProvider(widget.listingId)),
        ),
      ),
      data: (listing) {
        final isOwner = listing.sellerId == currentUserId;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 280,
                backgroundColor: CartokColors.background,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: CartokColors.textPrimary),
                    tooltip: 'Share',
                    onPressed: () => shareText(
                      text: 'Check out "${listing.title}" (${listing.formattedPrice}) on Cartok!',
                      subject: listing.title,
                    ),
                  ),
                  if (!isOwner)
                    IconButton(
                      icon: _togglingFavorite
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: CartokColors.textPrimary),
                            )
                          : Icon(
                              _isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: _isFavorited ? CartokColors.redline : CartokColors.textPrimary,
                            ),
                      onPressed: _togglingFavorite ? null : _toggleFavorite,
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: listing.images.isNotEmpty
                      ? PageView.builder(
                          itemCount: listing.images.length,
                          itemBuilder: (context, index) => CachedNetworkImage(
                            imageUrl: listing.images[index].url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: CartokColors.surfaceElevated),
                          ),
                        )
                      : Container(
                          color: CartokColors.surfaceElevated,
                          child: const Icon(Icons.directions_car_filled_rounded,
                              size: 64, color: CartokColors.textTertiary),
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing.formattedPrice,
                          style: textTheme.displayMedium?.copyWith(color: CartokColors.redline)),
                      const SizedBox(height: 8),
                      Text(listing.title, style: textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _Tag(label: listing.type.replaceAll('_', ' ')),
                          if (listing.condition != null) _Tag(label: listing.condition!),
                          if (listing.location != null)
                            _Tag(label: listing.location!, icon: Icons.place_outlined),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Description', style: textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Text(listing.description, style: textTheme.bodyLarge),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.visibility_outlined, size: 16, color: CartokColors.textTertiary),
                          const SizedBox(width: 6),
                          Text('${listing.viewCount} views', style: textTheme.bodyMedium),
                        ],
                      ),
                      if (isOwner && listing.status == 'ACTIVE') ...[
                        const SizedBox(height: 28),
                        OutlinedButton(onPressed: _markSold, child: const Text('Mark as sold')),
                      ],
                      if (listing.status == 'SOLD') ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: CartokColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('This item has been sold', textAlign: TextAlign.center),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: CartokColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CartokColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: CartokColors.textSecondary), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
