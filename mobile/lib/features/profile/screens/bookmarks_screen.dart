import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_empty_state.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../../forum/providers/forum_providers.dart';
import '../../forum/screens/widgets/thread_list_item.dart';
import '../../garage/providers/garage_providers.dart';
import '../../garage/screens/widgets/vehicle_card.dart';

final _bookmarkedVehiclesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(garageRepositoryProvider).listBookmarkedVehicles();
});

final _bookmarkedThreadsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(forumRepositoryProvider).listBookmarkedThreads();
});

class BookmarksScreen extends ConsumerWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bookmarks'),
          bottom: const TabBar(
            indicatorColor: CartokColors.redline,
            labelColor: CartokColors.textPrimary,
            unselectedLabelColor: CartokColors.textTertiary,
            tabs: [
              Tab(text: 'Vehicles'),
              Tab(text: 'Threads'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _BookmarkedVehiclesTab(),
            _BookmarkedThreadsTab(),
          ],
        ),
      ),
    );
  }
}

class _BookmarkedVehiclesTab extends ConsumerWidget {
  const _BookmarkedVehiclesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(_bookmarkedVehiclesProvider);

    return RefreshIndicator(
      color: CartokColors.redline,
      backgroundColor: CartokColors.surfaceElevated,
      onRefresh: () async => ref.invalidate(_bookmarkedVehiclesProvider),
      child: vehiclesAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 88,
              decoration: BoxDecoration(color: CartokColors.surface, borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        error: (err, _) => CartokErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(_bookmarkedVehiclesProvider),
        ),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return const CartokEmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'No bookmarked vehicles',
              message: 'Tap the bookmark icon on any vehicle to save it here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return VehicleCard(
                vehicle: vehicle,
                onTap: () => context.push('/garage/vehicle/${vehicle.garageId}/${vehicle.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

class _BookmarkedThreadsTab extends ConsumerWidget {
  const _BookmarkedThreadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(_bookmarkedThreadsProvider);

    return RefreshIndicator(
      color: CartokColors.redline,
      backgroundColor: CartokColors.surfaceElevated,
      onRefresh: () async => ref.invalidate(_bookmarkedThreadsProvider),
      child: threadsAsync.when(
        loading: () => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 96,
              decoration: BoxDecoration(color: CartokColors.surface, borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        error: (err, _) => CartokErrorState(
          message: err.toString(),
          onRetry: () => ref.invalidate(_bookmarkedThreadsProvider),
        ),
        data: (threads) {
          if (threads.isEmpty) {
            return const CartokEmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'No bookmarked threads',
              message: 'Tap the bookmark icon on any thread to save it here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final thread = threads[index];
              return ThreadListItem(
                thread: thread,
                onTap: () => context.push('/forum/thread/${thread.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
