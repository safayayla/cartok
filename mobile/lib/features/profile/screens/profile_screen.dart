import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../../auth/providers/auth_notifier.dart';
import '../../messaging/providers/conversation_list_provider.dart';
import '../providers/profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileProvider(username));
    final currentUsername = ref.watch(authNotifierProvider.select((s) => s.user?.username));
    final isOwnProfile = currentUsername == username;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('@$username'),
        actions: [
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.bookmark_border_rounded),
              tooltip: 'Bookmarks',
              onPressed: () => context.push('/bookmarks'),
            ),
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit profile',
              onPressed: () => context.push('/profile/edit'),
            ),
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Log out',
              onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: CartokColors.redline,
        backgroundColor: CartokColors.surfaceElevated,
        onRefresh: () => ref.read(profileProvider(username).notifier).load(),
        child: _buildBody(context, ref, state, isOwnProfile, textTheme),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ProfileState state,
    bool isOwnProfile,
    TextTheme textTheme,
  ) {
    if (state.isLoading) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(color: CartokColors.surface, shape: BoxShape.circle),
            ),
          ),
        ],
      );
    }

    if (state.error != null || state.profile == null) {
      return CartokErrorState(
        message: state.error?.toString() ?? 'Profile not found',
        onRetry: () => ref.read(profileProvider(username).notifier).load(),
      );
    }

    final profile = state.profile!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: CartokColors.surfaceElevated,
            backgroundImage: profile.avatarUrl != null ? CachedNetworkImageProvider(profile.avatarUrl!) : null,
            child: profile.avatarUrl == null
                ? Text(
                    profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?',
                    style: textTheme.displayMedium,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(profile.displayName, style: textTheme.headlineSmall),
              if (profile.verification == 'VERIFIED') ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded, size: 18, color: CartokColors.verified),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        Center(child: Text('@${profile.username}', style: textTheme.bodyMedium)),
        if (profile.bio != null && profile.bio!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(profile.bio!, style: textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StatButton(
              count: profile.followerCount,
              label: 'Followers',
              onTap: () => context.push('/profile/$username/followers'),
            ),
            const SizedBox(width: 32),
            _StatButton(
              count: profile.followingCount,
              label: 'Following',
              onTap: () => context.push('/profile/$username/following'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (!isOwnProfile)
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await ref.read(profileProvider(username).notifier).toggleFollow();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  style: profile.isFollowedByMe
                      ? ElevatedButton.styleFrom(
                          backgroundColor: CartokColors.surfaceElevated,
                          foregroundColor: CartokColors.textPrimary,
                        )
                      : null,
                  child: Text(profile.isFollowedByMe ? 'Following' : 'Follow'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      final conversation =
                          await ref.read(messagingRepositoryProvider).getOrCreateDm(username);
                      if (context.mounted) {
                        context.push('/messages/${conversation.id}', extra: profile.displayName);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
                  child: const Text('Message'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _StatButton extends StatelessWidget {
  const _StatButton({required this.count, required this.label, required this.onTap});

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Text('$count', style: textTheme.titleMedium),
            Text(label, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
