import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/cartok_colors.dart';
import '../../models/cartok_listing.dart';

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, required this.onTap});

  final CartokListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final thumbnail = listing.images.isNotEmpty ? listing.images.first.url : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: thumbnail != null
                  ? CachedNetworkImage(
                      imageUrl: thumbnail,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: CartokColors.surfaceElevated),
                      errorWidget: (context, url, error) => Container(
                        color: CartokColors.surfaceElevated,
                        child: const Icon(Icons.image_not_supported_outlined, color: CartokColors.textTertiary),
                      ),
                    )
                  : Container(
                      color: CartokColors.surfaceElevated,
                      child: const Icon(Icons.directions_car_filled_rounded, color: CartokColors.textTertiary, size: 32),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.formattedPrice,
                    style: textTheme.titleMedium?.copyWith(color: CartokColors.redline),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    listing.title,
                    style: textTheme.bodyMedium?.copyWith(color: CartokColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (listing.status == 'SOLD') ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CartokColors.surfaceSunken,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('SOLD', style: textTheme.labelSmall?.copyWith(color: CartokColors.danger)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
