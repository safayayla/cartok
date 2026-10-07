import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/theme/cartok_typography.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../../../core/utils/share_helper.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../auth/repository/auth_repository.dart';
import '../providers/event_detail_provider.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  String _formatDateTime(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} · $hour12:$minute $ampm';
  }

  Future<void> _handleRsvp(BuildContext context, WidgetRef ref, String status) async {
    try {
      await ref.read(eventDetailProvider(eventId).notifier).setStatus(status);
    } on ApiException catch (e) {
      if (context.mounted) {
        final message = e.statusCode == 409 ? 'This event is full.' : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _handleCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CartokColors.surfaceElevated,
        title: const Text('Cancel this event?'),
        content: const Text('Everyone who RSVP\'d will be notified. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep event')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel event', style: TextStyle(color: CartokColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(eventDetailProvider(eventId).notifier).cancelEvent();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(eventDetailProvider(eventId));
    final currentUserId = ref.watch(authNotifierProvider.select((s) => s.user?.id));
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (state.event != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: () => shareText(
                text: 'Join me at "${state.event!.title}" on Cartok — ${state.event!.locationName}',
                subject: state.event!.title,
              ),
            ),
          if (state.event != null && state.event!.hostId == currentUserId && !state.event!.isCancelled)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'cancel') _handleCancel(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'cancel', child: Text('Cancel event')),
              ],
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: CartokColors.redline))
          : state.error != null || state.event == null
              ? CartokErrorState(
                  message: state.error?.toString() ?? 'Event not found',
                  onRetry: () => ref.read(eventDetailProvider(eventId).notifier).load(),
                )
              : _buildBody(context, ref, state, currentUserId, textTheme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    EventDetailState state,
    String? currentUserId,
    TextTheme textTheme,
  ) {
    final event = state.event!;
    final isHost = event.hostId == currentUserId;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (event.isCancelled)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: CartokColors.danger.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CartokColors.danger.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.cancel_outlined, size: 16, color: CartokColors.danger),
                const SizedBox(width: 8),
                const Text('This event was cancelled', style: TextStyle(color: CartokColors.danger)),
              ],
            ),
          ),
        Text(
          event.typeLabel.toUpperCase(),
          style: CartokTypography.telemetry(size: 12, color: CartokColors.telemetry, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(event.title, style: textTheme.displayMedium),
        const SizedBox(height: 20),
        _InfoRow(icon: Icons.schedule_rounded, text: _formatDateTime(event.startTime)),
        const SizedBox(height: 10),
        _InfoRow(icon: Icons.location_on_outlined, text: event.locationName),
        const SizedBox(height: 10),
        _InfoRow(
          icon: Icons.people_outline_rounded,
          text: event.capacity != null
              ? '${event.goingCount} / ${event.capacity} going'
              : '${event.goingCount} going',
        ),
        if (event.host != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: CartokColors.surfaceElevated,
                child: Text(
                  event.host!.displayName.isNotEmpty ? event.host!.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Text('Hosted by ${event.host!.displayName}', style: textTheme.bodyMedium),
            ],
          ),
        ],
        if (event.description != null && event.description!.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(event.description!, style: textTheme.bodyLarge),
        ],
        const SizedBox(height: 28),
        if (!event.isCancelled) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: event.isFull && state.myStatus != 'GOING'
                      ? null
                      : () => _handleRsvp(context, ref, state.myStatus == 'GOING' ? 'NOT_GOING' : 'GOING'),
                  style: state.myStatus == 'GOING'
                      ? null
                      : ElevatedButton.styleFrom(
                          backgroundColor: CartokColors.surfaceElevated,
                          foregroundColor: CartokColors.textPrimary,
                        ),
                  child: Text(state.myStatus == 'GOING' ? "You're going · tap to leave" : 'Going'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      _handleRsvp(context, ref, state.myStatus == 'INTERESTED' ? 'NOT_GOING' : 'INTERESTED'),
                  style: state.myStatus == 'INTERESTED'
                      ? OutlinedButton.styleFrom(
                          side: const BorderSide(color: CartokColors.telemetry, width: 1.5),
                        )
                      : null,
                  child: Text(state.myStatus == 'INTERESTED' ? 'Interested ✓' : 'Interested'),
                ),
              ),
            ],
          ),
        ],
        if (isHost && !event.isCancelled) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text('Check-in code', style: textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(
            'Share this with attendees at the event to check them in.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          SelectableText(event.checkInCode, style: CartokTypography.telemetry(size: 14, color: CartokColors.telemetry)),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: CartokColors.textTertiary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    );
  }
}
