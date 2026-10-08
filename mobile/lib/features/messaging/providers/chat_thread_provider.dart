import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cartok_message.dart';
import '../repository/messaging_repository.dart';
import 'conversation_list_provider.dart';

class ChatThreadState {
  const ChatThreadState({
    this.messages = const [],
    this.nextCursor,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.pendingIds = const {},
  });

  /// Newest-first, matching the API's order directly (renders with
  /// ListView(reverse: true), so index 0 lands at the bottom of the screen).
  final List<CartokMessage> messages;
  final String? nextCursor;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  // Locally-created optimistic message ids not yet confirmed by the server.
  final Set<String> pendingIds;

  bool get hasMore => nextCursor != null;

  ChatThreadState copyWith({
    List<CartokMessage>? messages,
    String? nextCursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error,
    bool clearError = false,
    Set<String>? pendingIds,
  }) =>
      ChatThreadState(
        messages: messages ?? this.messages,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        pendingIds: pendingIds ?? this.pendingIds,
      );
}

class ChatThreadNotifier extends StateNotifier<ChatThreadState> {
  ChatThreadNotifier(this._repository, this._conversationId) : super(const ChatThreadState()) {
    _load();
    // Polling, not a WebSocket push — this backend doesn't have a realtime
    // channel yet (see messaging.service.ts's REST-only design). Polling
    // every few seconds while the thread is open is an honest, working
    // stand-in: messages still arrive without a manual refresh, just not
    // instantly. Swap this for a socket subscription without changing the
    // state shape or the UI once that infrastructure exists.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  final MessagingRepository _repository;
  final String _conversationId;
  Timer? _pollTimer;

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _repository.listMessages(_conversationId);
      state = state.copyWith(
        messages: page.items,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoading: false,
      );
      unawaited(_repository.markRead(_conversationId));
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> _poll() async {
    if (state.isLoading || state.error != null) return;
    try {
      final page = await _repository.listMessages(_conversationId);
      final existingIds = state.messages.map((m) => m.id).toSet();
      final newOnes = page.items.where((m) => !existingIds.contains(m.id));
      if (newOnes.isEmpty) return;

      final merged = [...newOnes, ...state.messages]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(messages: merged);
      unawaited(_repository.markRead(_conversationId));
    } catch (_) {
      // A single missed poll shouldn't surface an error to the user — the
      // next tick tries again. Only the initial load surfaces failures.
    }
  }

  /// Re-runs the initial load — used by the error state's "Retry" button.
  /// Named distinctly from `_load` (private, constructor-only) so the retry
  /// path is an explicit, public entry point rather than exposing the
  /// internal method itself.
  Future<void> refresh() => _load();

  Future<void> loadOlder() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repository.listMessages(_conversationId, cursor: state.nextCursor);
      final existingIds = state.messages.map((m) => m.id).toSet();
      final older = page.items.where((m) => !existingIds.contains(m.id));
      state = state.copyWith(
        messages: [...state.messages, ...older],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Optimistic send: a locally-built message appears immediately at the
  /// bottom of the thread; once the real one comes back it replaces the
  /// local placeholder by id. If the send fails, the placeholder is removed
  /// and the caller (the UI) is responsible for telling the user.
  Future<void> send(String content, String currentUserId) async {
    final tempId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = CartokMessage(
      id: tempId,
      conversationId: _conversationId,
      senderId: currentUserId,
      content: content,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [optimistic, ...state.messages],
      pendingIds: {...state.pendingIds, tempId},
    );

    try {
      final real = await _repository.sendMessage(_conversationId, content);
      state = state.copyWith(
        messages: [for (final m in state.messages) if (m.id == tempId) real else m],
        pendingIds: {...state.pendingIds}..remove(tempId),
      );
    } catch (e) {
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != tempId).toList(),
        pendingIds: {...state.pendingIds}..remove(tempId),
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final chatThreadProvider = StateNotifierProvider.family<ChatThreadNotifier, ChatThreadState, String>(
  (ref, conversationId) {
    final notifier = ChatThreadNotifier(ref.watch(messagingRepositoryProvider), conversationId);
    // Refreshes the conversation list's unread badges once the user leaves
    // this thread, since messages read here won't show as unread anymore.
    ref.onDispose(() {
      ref.read(conversationListProvider.notifier).load();
    });
    return notifier;
  },
);
