import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_dependencies_provider.dart';
import '../models/cartok_forum_category.dart';
import '../repository/forum_repository.dart';

final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  return ForumRepository(ref.watch(apiClientProvider));
});

final forumCategoriesProvider = FutureProvider<List<CartokForumCategory>>((ref) {
  return ref.watch(forumRepositoryProvider).listCategories();
});
