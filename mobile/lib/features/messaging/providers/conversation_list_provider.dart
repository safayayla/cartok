import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_dependencies_provider.dart';
import '../models/cartok_message.dart';
import '../repository/messaging_repository.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepository(ref.watch(apiClientProvider));
});

class ConversationListState {
  const ConversationListState({this.items = const [], this.isLoading = true, this.error});

  final List<CartokConversationSummary> items;
  final bool isLoading;
  final Object? error;

  ConversationListState copyWith({
    List<CartokConversationSummary>? items,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) =>
      ConversationListState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class ConversationListNotifier extends StateNotifier<ConversationListState> {
  ConversationListNotifier(this._repository) : super(const ConversationListState()) {
    load();
  }

  final MessagingRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _repository.listConversations();
      state = state.copyWith(items: page.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }
}

final conversationListProvider = StateNotifierProvider<ConversationListNotifier, ConversationListState>((ref) {
  return ConversationListNotifier(ref.watch(messagingRepositoryProvider));
});
