import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/cartok_colors.dart';
import '../../../core/widgets/cartok_empty_state.dart';
import '../../../core/widgets/cartok_error_state.dart';
import '../providers/forum_providers.dart';

class ForumCategoriesScreen extends ConsumerWidget {
  const ForumCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(forumCategoriesProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Forum')),
      body: RefreshIndicator(
        color: CartokColors.redline,
        backgroundColor: CartokColors.surfaceElevated,
        onRefresh: () async => ref.invalidate(forumCategoriesProvider),
        child: categoriesAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(16),
            children: List.generate(
              5,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: CartokColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                  onRetry: () => ref.invalidate(forumCategoriesProvider),
                ),
              ),
            ],
          ),
          data: (categories) {
            if (categories.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: const CartokEmptyState(
                      icon: Icons.forum_outlined,
                      title: 'No categories yet',
                      message: 'Check back soon — the forum is just getting started.',
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final category = categories[index];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.push('/forum/${category.id}', extra: category.name),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: CartokColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.forum_rounded, color: CartokColors.telemetry, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(category.name, style: textTheme.titleMedium),
                                if (category.description != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    category.description!,
                                    style: textTheme.bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: CartokColors.textTertiary),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
