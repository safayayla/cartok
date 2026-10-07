import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_empty_state.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../providers/event_list_provider.dart';
import 'widgets/event_card.dart';

const _typeFilters = <String?, String>{
  null: 'All',
  'CARS_AND_COFFEE': 'Cars & Coffee',
  'DRIVE_TOGETHER': 'Drive Together',
  'TRACK_DAY': 'Track Day',
  'MEETUP': 'Meetup',
};

class EventListScreen extends ConsumerStatefulWidget {
  const EventListScreen({super.key});

  @override
  ConsumerState<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends ConsumerState<EventListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      ref.read(eventListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/events/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Host event'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: _typeFilters.entries.map((entry) {
                final selected = state.selectedType == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) => ref.read(eventListProvider.notifier).setType(entry.key),
                    selectedColor: CartokColors.redline,
                    backgroundColor: CartokColors.surfaceElevated,
                    labelStyle: TextStyle(
                      color: selected ? CartokColors.textOnAccent : CartokColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: selected ? CartokColors.redline : CartokColors.borderSubtle),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: CartokColors.redline,
              backgroundColor: CartokColors.surfaceElevated,
              onRefresh: () => ref.read(eventListProvider.notifier).refresh(),
              child: _buildBody(state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(EventListState state) {
    if (state.isInitialLoading) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 104,
              decoration: BoxDecoration(color: CartokColors.surface, borderRadius: BorderRadius.circular(16)),
            ),
          ),
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
              onRetry: () => ref.read(eventListProvider.notifier).refresh(),
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
              icon: Icons.event_outlined,
              title: 'No upcoming events',
              message: 'Be the first to host a Cars & Coffee or plan a drive.',
              actionLabel: 'Host an event',
              onAction: () => context.push('/events/new'),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: CartokColors.telemetry),
              ),
            ),
          );
        }
        final event = state.items[index];
        return EventCard(event: event, onTap: () => context.push('/events/${event.id}'));
      },
    );
  }
}
