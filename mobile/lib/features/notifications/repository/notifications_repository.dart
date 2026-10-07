import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../auth/repository/auth_repository.dart';
import '../models/cartok_notification.dart';

class NotificationPage {
  const NotificationPage({required this.items, this.nextCursor});
  final List<CartokNotification> items;
  final String? nextCursor;
}

class NotificationsRepository {
  NotificationsRepository(this._client);

  final ApiClient _client;

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    final message = (data is Map && data['error'] != null)
        ? (data['error']['message'] as String? ?? 'Something went wrong')
        : 'Network error — please check your connection';
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  Future<NotificationPage> list({String? cursor, int limit = 20}) async {
    try {
      final res = await _client.dio.get(
        '/api/v1/notifications',
        queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
      );
      final items = (res.data['data'] as List<dynamic>)
          .map((n) => CartokNotification.fromJson(n as Map<String, dynamic>))
          .toList();
      return NotificationPage(items: items, nextCursor: res.data['nextCursor'] as String?);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<int> unreadCount() async {
    try {
      final res = await _client.dio.get('/api/v1/notifications/unread-count');
      return res.data['data']['count'] as int;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await _client.dio.post('/api/v1/notifications/$notificationId/read');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> markAllRead() async {
    try {
      await _client.dio.post('/api/v1/notifications/read-all');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}
