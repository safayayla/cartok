import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_empty_state.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../models/cartok_public_profile.dart';
import '../providers/profile_providers.dart';

enum FollowListMode { followers, following }

final _followListProvider = FutureProvider.autoDispose.family<List<CartokFollowUser>, (String, FollowListMode)>(
  (ref, args) async {
    final (username, mode) = args;
    final repo = ref.watch(profileRepositoryProvider);
    final page =
        mode == FollowListMode.followers ? await repo.listFollowers(username) : await repo.listFollowing(username);
    return page.items;
  },
);

class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({super.key, required this.username, required this.mode});

  final String username;
  final FollowListMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (username, mode);
    final listAsync = ref.watch(_followListProvider(key));
    final title = mode == FollowListMode.followers ? 'Followers' : 'Following';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        color: CartokColors.redline,
        backgroundColor: CartokColors.surfaceElevated,
        onRefresh: () async => ref.invalidate(_followListProvider(key)),
        child: listAsync.when(
          loading: () => ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: 6,
            itemBuilder: (context, index) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SizedBox(height: 48),
            ),
          ),
          error: (err, _) => CartokErrorState(
            message: err.toString(),
            onRetry: () => ref.invalidate(_followListProvider(key)),
          ),
          data: (users) {
            if (users.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: CartokEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: mode == FollowListMode.followers ? 'No followers yet' : 'Not following anyone yet',
                      message: mode == FollowListMode.followers
                          ? 'When someone follows this account, they\'ll show up here.'
                          : 'Accounts they follow will show up here.',
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: CartokColors.surfaceElevated,
                    backgroundImage: user.avatarUrl != null ? CachedNetworkImageProvider(user.avatarUrl!) : null,
                    child: user.avatarUrl == null
                        ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?')
                        : null,
                  ),
                  title: Text(user.displayName),
                  subtitle: Text('@${user.username}'),
                  onTap: () => context.push('/profile/${user.username}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
