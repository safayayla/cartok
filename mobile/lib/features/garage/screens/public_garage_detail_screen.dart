import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../../../core/widgets/cartok_empty_state.dart';
import '../../auth/providers/auth_notifier.dart';
import '../providers/public_garage_provider.dart';
import 'widgets/vehicle_card.dart';

class PublicGarageDetailScreen extends ConsumerWidget {
  const PublicGarageDetailScreen({super.key, required this.garageId});

  final String garageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(publicGarageProvider(garageId));
    final currentUserId = ref.watch(authNotifierProvider.select((s) => s.user?.id));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(state.garage?.name ?? 'Garage')),
      body: RefreshIndicator(
        color: CartokColors.redline,
        backgroundColor: CartokColors.surfaceElevated,
        onRefresh: () => ref.read(publicGarageProvider(garageId).notifier).load(),
        child: _buildBody(context, ref, state, currentUserId, textTheme),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    PublicGarageState state,
    String? currentUserId,
    TextTheme textTheme,
  ) {
    if (state.isLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 88,
              decoration: BoxDecoration(color: CartokColors.surface, borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      );
    }

    if (state.error != null || state.garage == null) {
      return CartokErrorState(
        message: state.error?.toString() ?? 'Garage not found',
        onRetry: () => ref.read(publicGarageProvider(garageId).notifier).load(),
      );
    }

    final garage = state.garage!;
    final isOwner = garage.ownerId == currentUserId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (garage.coverUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: garage.coverUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(height: 160, color: CartokColors.surface),
              errorWidget: (context, url, error) => Container(height: 160, color: CartokColors.surface),
            ),
          ),
        if (garage.coverUrl != null) const SizedBox(height: 16),
        Text(garage.name, style: textTheme.displayMedium),
        if (garage.description != null && garage.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(garage.description!, style: textTheme.bodyLarge),
        ],
        const SizedBox(height: 12),
        Text('${garage.followerCount} followers · ${garage.vehicles.length} vehicles', style: textTheme.bodyMedium),
        if (!isOwner) ...[
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(publicGarageProvider(garageId).notifier).toggleFollow();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            style: garage.isFollowedByMe
                ? ElevatedButton.styleFrom(
                    backgroundColor: CartokColors.surfaceElevated,
                    foregroundColor: CartokColors.textPrimary,
                  )
                : null,
            child: Text(garage.isFollowedByMe ? 'Following' : 'Follow'),
          ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text('Vehicles', style: textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (garage.vehicles.isEmpty)
          const CartokEmptyState(
            icon: Icons.directions_car_outlined,
            title: 'No public vehicles',
            message: 'This garage hasn\'t shared any vehicles publicly yet.',
          )
        else
          ...garage.vehicles.map(
            (vehicle) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: VehicleCard(vehicle: vehicle),
            ),
          ),
      ],
    );
  }
}
