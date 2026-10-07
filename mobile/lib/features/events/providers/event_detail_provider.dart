import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/repository/auth_repository.dart';
import '../models/cartok_event.dart';
import '../repository/events_repository.dart';

class EventDetailState {
  const EventDetailState({this.event, this.myStatus, this.isLoading = true, this.error});

  final CartokEvent? event;
  // Not returned by GET /events/:id today (no per-user RSVP state in that
  // response) - tracked client-side from the result of the RSVP call
  // itself, so the button reflects what the user just did without a second
  // round trip. Resets to unknown on next full reload, same trade-off as
  // the forum's per-user vote state.
  final String? myStatus;
  final bool isLoading;
  final Object? error;

  EventDetailState copyWith({
    CartokEvent? event,
    String? myStatus,
    bool? isLoading,
    Object? error,
    bool clearError = false,
  }) =>
      EventDetailState(
        event: event ?? this.event,
        myStatus: myStatus ?? this.myStatus,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class EventDetailNotifier extends StateNotifier<EventDetailState> {
  EventDetailNotifier(this._repository, this._eventId) : super(const EventDetailState()) {
    load();
  }

  final EventsRepository _repository;
  final String _eventId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final event = await _repository.getById(_eventId);
      state = state.copyWith(event: event, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Optimistic for the common case (GOING, room available): the button and
  /// count update immediately. If the backend rejects it (409 = at
  /// capacity, since that check can only be authoritative server-side), the
  /// optimistic change is rolled back and the specific capacity error is
  /// surfaced rather than a generic one.
  Future<void> setStatus(String status) async {
    final event = state.event;
    if (event == null) return;

    final previousStatus = state.myStatus;
    final previousEvent = event;

    final goingDelta = switch ((previousStatus, status)) {
      (final prev, 'GOING') when prev != 'GOING' => 1,
      (final prev, final next) when prev == 'GOING' && next != 'GOING' => -1,
      _ => 0,
    };

    state = state.copyWith(
      myStatus: status,
      event: goingDelta != 0 ? event.copyWith(goingCount: event.goingCount + goingDelta) : event,
    );

    try {
      final confirmedStatus = await _repository.rsvp(_eventId, status);
      state = state.copyWith(myStatus: confirmedStatus);
    } on ApiException catch (e) {
      state = state.copyWith(myStatus: previousStatus, event: previousEvent);
      rethrow;
    }
  }

  Future<void> cancelEvent() async {
    await _repository.cancel(_eventId);
    await load();
  }
}

final eventDetailProvider = StateNotifierProvider.family<EventDetailNotifier, EventDetailState, String>(
  (ref, eventId) => EventDetailNotifier(ref.watch(eventsRepositoryProvider), eventId),
);
