import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_dependencies_provider.dart';
import '../models/cartok_feed_item.dart';
import '../repository/discover_repository.dart';

final discoverRepositoryProvider = Provider<DiscoverRepository>((ref) {
  return DiscoverRepository(ref.watch(apiClientProvider));
});

final feedProvider = FutureProvider.autoDispose<List<CartokFeedItem>>((ref) {
  return ref.watch(discoverRepositoryProvider).getFeed();
});
