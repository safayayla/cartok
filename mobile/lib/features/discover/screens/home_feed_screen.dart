import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_empty_state.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../models/cartok_feed_item.dart';
import '../providers/discover_providers.dart';
import 'widgets/feed_cards.dart';

class HomeFeedScreen extends ConsumerWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('For You'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded),
            tooltip: 'Messages',
            onPressed: () => context.push('/messages'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: CartokColors.redline,
        backgroundColor: CartokColors.surfaceElevated,
        onRefresh: () async => ref.invalidate(feedProvider),
        child: feedAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: List.generate(
              5,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  height: 96,
                  decoration: BoxDecoration(color: CartokColors.surface, borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
          error: (err, _) => ListView(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: CartokErrorState(
                  message: err.toString(),
                  onRetry: () => ref.invalidate(feedProvider),
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const CartokEmptyState(
                      icon: Icons.explore_outlined,
                      title: 'Nothing to show yet',
                      message: 'Follow garages, join threads, or RSVP to events to see them here.',
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) => _buildItem(context, items[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, CartokFeedItem item) {
    switch (item.itemType) {
      case CartokFeedItemType.vehicle:
        final v = item.vehicle!;
        return FeedVehicleCard(
          vehicle: v,
          onTap: () => context.push('/garage/vehicle/${v.garageId}/${v.id}'),
        );
      case CartokFeedItemType.thread:
        final t = item.thread!;
        return FeedThreadCard(thread: t, onTap: () => context.push('/forum/thread/${t.id}'));
      case CartokFeedItemType.event:
        final e = item.event!;
        return FeedEventCard(event: e, onTap: () => context.push('/events/${e.id}'));
    }
  }
}
