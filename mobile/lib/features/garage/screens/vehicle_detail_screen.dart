import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/theme/cartok_typography.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../../../core/utils/share_helper.dart';
import '../../auth/providers/auth_notifier.dart';
import '../models/cartok_vehicle.dart';
import '../providers/garage_providers.dart';
import '../providers/vehicle_detail_provider.dart';

class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({super.key, required this.garageId, required this.vehicleId});

  final String garageId;
  final String vehicleId;

  @override
  ConsumerState<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  final _commentController = TextEditingController();
  bool _sendingComment = false;

  (String, String) get _key => (widget.garageId, widget.vehicleId);

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    try {
      await ref.read(vehicleDetailProvider(_key).notifier).toggleLike();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Like failed: $e')));
      }
    }
  }

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    setState(() => _sendingComment = true);
    try {
      await ref.read(vehicleDetailProvider(_key).notifier).addComment(content);
      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CartokColors.surfaceElevated,
        title: const Text('Remove this vehicle?'),
        content: const Text('This removes it from your garage. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: CartokColors.danger)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(garageRepositoryProvider)
          .deleteVehicle(garageId: widget.garageId, vehicleId: widget.vehicleId);
      ref.invalidate(myGaragesProvider);
      ref.invalidate(garageDetailProvider(widget.garageId));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehicleDetailProvider(_key));
    final currentUserId = ref.watch(authNotifierProvider.select((s) => s.user?.id));
    final textTheme = Theme.of(context).textTheme;

    // No extra network call: myGaragesProvider is already loaded/cached for
    // the garage tab, and "is this garage mine" is exactly the ownership
    // question the delete action needs answered.
    final myGarages = ref.watch(myGaragesProvider).value ?? [];
    final isOwner = myGarages.any((g) => g.id == widget.garageId);

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (state.vehicle != null)
            IconButton(
              icon: Icon(
                state.vehicle!.isBookmarkedByMe ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: state.vehicle!.isBookmarkedByMe ? CartokColors.telemetry : null,
              ),
              tooltip: state.vehicle!.isBookmarkedByMe ? 'Remove bookmark' : 'Bookmark',
              onPressed: () async {
                try {
                  await ref.read(vehicleDetailProvider(_key).notifier).toggleBookmark();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bookmark failed: $e')));
                  }
                }
              },
            ),
          if (state.vehicle != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: () => shareText(
                text: 'Check out this ${state.vehicle!.title} on Cartok!',
                subject: state.vehicle!.title,
              ),
            ),
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') await _confirmDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Remove vehicle')),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator(color: CartokColors.redline))
            : state.error != null || state.vehicle == null
                ? CartokErrorState(
                    message: state.error?.toString() ?? 'Vehicle not found',
                    onRetry: () => ref.read(vehicleDetailProvider(_key).notifier).load(),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: _buildContent(context, state, currentUserId, textTheme),
                      ),
                      _buildComposer(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, VehicleDetailState state, String? currentUserId, TextTheme textTheme) {
    final vehicle = state.vehicle!;
    final isVerified = vehicle.verificationStatus == 'VERIFIED';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(child: Text(vehicle.title, style: textTheme.displayMedium)),
            if (isVerified) const Icon(Icons.verified_rounded, color: CartokColors.verified, size: 24),
          ],
        ),
        const SizedBox(height: 4),
        Text(vehicle.subtitle, style: textTheme.bodyLarge?.copyWith(color: CartokColors.textSecondary)),
        const SizedBox(height: 20),
        Row(
          children: [
            InkWell(
              onTap: _toggleLike,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        vehicle.isLikedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        key: ValueKey(vehicle.isLikedByMe),
                        color: vehicle.isLikedByMe ? CartokColors.redline : CartokColors.textSecondary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${vehicle.likeCount}', style: textTheme.bodyLarge),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            const Icon(Icons.chat_bubble_outline_rounded, color: CartokColors.textSecondary, size: 20),
            const SizedBox(width: 6),
            Text('${vehicle.commentCount}', style: textTheme.bodyLarge),
          ],
        ),
        const SizedBox(height: 24),
        _DetailCard(vehicle: vehicle),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Text('Comments', style: textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (state.isLoadingComments && state.comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: CartokColors.telemetry)),
          )
        else if (state.comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No comments yet. Be the first to say something.', style: textTheme.bodyMedium),
          )
        else
          ...state.comments.map(
            (comment) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: CartokColors.surfaceElevated,
                    backgroundImage:
                        comment.author.avatarUrl != null ? CachedNetworkImageProvider(comment.author.avatarUrl!) : null,
                    child: comment.author.avatarUrl == null
                        ? Text(
                            comment.author.displayName.isNotEmpty ? comment.author.displayName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 12),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(comment.author.displayName, style: textTheme.labelLarge),
                            if (comment.editedAt != null) ...[
                              const SizedBox(width: 6),
                              Text('(edited)', style: textTheme.labelSmall),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          comment.content,
                          style: comment.isDeleted
                              ? textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)
                              : textTheme.bodyMedium?.copyWith(color: CartokColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  if (!comment.isDeleted && comment.authorId == currentUserId)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: CartokColors.textTertiary),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref.read(vehicleDetailProvider(_key).notifier).deleteComment(comment.id),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 20),
      decoration: const BoxDecoration(
        color: CartokColors.surface,
        border: Border(top: BorderSide(color: CartokColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: Theme.of(context).textTheme.bodyLarge,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Add a comment...'),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: _sendingComment ? null : _sendComment,
            style: IconButton.styleFrom(backgroundColor: CartokColors.redline),
            icon: _sendingComment
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CartokColors.textOnAccent),
                  )
                : const Icon(Icons.arrow_upward_rounded, color: CartokColors.textOnAccent),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.vehicle});

  final CartokVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      if (vehicle.vin != null) MapEntry('VIN', vehicle.vin!),
      if (vehicle.odometer != null) MapEntry('Odometer', '${vehicle.odometer} ${vehicle.odometerUnit}'),
      MapEntry('Verification', vehicle.verificationStatus.toLowerCase()),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final row in rows) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(row.key, style: Theme.of(context).textTheme.bodyMedium),
                  Text(row.value, style: CartokTypography.telemetry(size: 14)),
                ],
              ),
              if (row != rows.last)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
