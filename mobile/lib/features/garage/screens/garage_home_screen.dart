import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_empty_state.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../../auth/providers/auth_notifier.dart';
import '../providers/garage_providers.dart';
import 'widgets/vehicle_card.dart';
import 'widgets/vehicle_card_skeleton.dart';
import 'create_garage_sheet.dart';

class GarageHomeScreen extends ConsumerWidget {
  const GarageHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garagesAsync = ref.watch(myGaragesProvider);
    final user = ref.watch(authNotifierProvider.select((state) => state.user));

    return Scaffold(
      appBar: AppBar(
        title: Text(user != null ? 'Hey, ${user.displayName.split(' ').first}' : 'My garage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () => context.push('/search'),
          ),
          if (user != null)
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: 'Profile',
              onPressed: () => context.push('/profile/${user.username}'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _handleAddVehicle(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add vehicle'),
      ),
      body: RefreshIndicator(
        color: CartokColors.redline,
        backgroundColor: CartokColors.surfaceElevated,
        onRefresh: () async => ref.invalidate(myGaragesProvider),
        child: garagesAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              VehicleCardSkeleton(),
              SizedBox(height: 12),
              VehicleCardSkeleton(),
              SizedBox(height: 12),
              VehicleCardSkeleton(),
            ],
          ),
          error: (err, _) => ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: CartokErrorState(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(myGaragesProvider),
                ),
              ),
            ],
          ),
          data: (garages) {
            if (garages.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: CartokEmptyState(
                      icon: Icons.garage_rounded,
                      title: 'Your garage is empty',
                      message: 'Create a garage, then add the first vehicle to your build.',
                      actionLabel: 'Create a garage',
                      onAction: () => _createGarage(context, ref),
                    ),
                  ),
                ],
              );
            }

            final allVehicles = garages.expand((g) => g.vehicles).toList();

            if (allVehicles.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: CartokEmptyState(
                      icon: Icons.directions_car_outlined,
                      title: 'No vehicles yet',
                      message: 'Add your first vehicle to start building its timeline.',
                      actionLabel: 'Add a vehicle',
                      onAction: () => _handleAddVehicle(context, ref),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: allVehicles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final vehicle = allVehicles[index];
                return VehicleCard(
                  vehicle: vehicle,
                  onTap: () => context.push('/garage/vehicle/${vehicle.garageId}/${vehicle.id}'),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleAddVehicle(BuildContext context, WidgetRef ref) async {
    final garages = ref.read(myGaragesProvider).value ?? [];
    if (garages.isEmpty) {
      await _createGarage(context, ref);
      return;
    }
    if (!context.mounted) return;
    context.push('/garage/add-vehicle/${garages.first.id}');
  }

  Future<void> _createGarage(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CartokColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CreateGarageSheet(),
    );
  }
}
