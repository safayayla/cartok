import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../auth/repository/auth_repository.dart';
import '../models/cartok_event.dart';

class EventPage {
  const EventPage({required this.items, this.nextCursor});
  final List<CartokEvent> items;
  final String? nextCursor;
}

class CartokAttendee {
  const CartokAttendee({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.status,
  });
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String status;

  factory CartokAttendee.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return CartokAttendee(
      id: user['id'] as String,
      username: user['username'] as String,
      displayName: user['displayName'] as String,
      avatarUrl: user['avatarUrl'] as String?,
      status: json['status'] as String,
    );
  }
}

class EventsRepository {
  EventsRepository(this._client);

  final ApiClient _client;

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    final message = (data is Map && data['error'] != null)
        ? (data['error']['message'] as String? ?? 'Something went wrong')
        : 'Network error — please check your connection';
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  Future<EventPage> list({String? type, String? cursor, int limit = 20}) async {
    try {
      final res = await _client.dio.get('/api/v1/events', queryParameters: {
        'limit': limit,
        if (type != null) 'type': type,
        if (cursor != null) 'cursor': cursor,
      });
      final items =
          (res.data['data'] as List<dynamic>).map((e) => CartokEvent.fromJson(e as Map<String, dynamic>)).toList();
      return EventPage(items: items, nextCursor: res.data['nextCursor'] as String?);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokEvent> getById(String eventId) async {
    try {
      final res = await _client.dio.get('/api/v1/events/$eventId');
      return CartokEvent.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokEvent> create({
    required String type,
    required String title,
    String? description,
    required String locationName,
    required DateTime startTime,
    DateTime? endTime,
    int? capacity,
  }) async {
    try {
      final res = await _client.dio.post('/api/v1/events', data: {
        'type': type,
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        'locationName': locationName,
        'startTime': startTime.toIso8601String(),
        if (endTime != null) 'endTime': endTime.toIso8601String(),
        if (capacity != null) 'capacity': capacity,
      });
      return CartokEvent.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Returns the new RSVP status. Throws ApiException(statusCode: 409) if
  /// the event is at capacity — callers should show that specific case
  /// distinctly rather than as a generic error.
  Future<String> rsvp(String eventId, String status) async {
    try {
      final res = await _client.dio.post('/api/v1/events/$eventId/rsvp', data: {'status': status});
      return res.data['data']['status'] as String;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> cancel(String eventId) async {
    try {
      await _client.dio.post('/api/v1/events/$eventId/cancel');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<CartokAttendee>> listAttendees(String eventId) async {
    try {
      final res = await _client.dio.get('/api/v1/events/$eventId/attendees');
      return (res.data['data'] as List<dynamic>).map((a) => CartokAttendee.fromJson(a as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> checkIn(String checkInCode) async {
    try {
      await _client.dio.post('/api/v1/events/check-in/$checkInCode');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}
