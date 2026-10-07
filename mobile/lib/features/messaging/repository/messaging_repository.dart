import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../auth/repository/auth_repository.dart';
import '../models/cartok_message.dart';

class MessagingPage<T> {
  const MessagingPage({required this.items, this.nextCursor});
  final List<T> items;
  final String? nextCursor;
}

class MessagingRepository {
  MessagingRepository(this._client);

  final ApiClient _client;

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    final message = (data is Map && data['error'] != null)
        ? (data['error']['message'] as String? ?? 'Something went wrong')
        : 'Network error — please check your connection';
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  Future<MessagingPage<CartokConversationSummary>> listConversations({String? cursor, int limit = 20}) async {
    try {
      final res = await _client.dio.get(
        '/api/v1/messaging/conversations',
        queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
      );
      final items = (res.data['data'] as List<dynamic>)
          .map((c) => CartokConversationSummary.fromJson(c as Map<String, dynamic>))
          .toList();
      return MessagingPage(items: items, nextCursor: res.data['nextCursor'] as String?);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokConversationDetail> getOrCreateDm(String username) async {
    try {
      final res = await _client.dio.post('/api/v1/messaging/conversations/dm/$username');
      return CartokConversationDetail.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<MessagingPage<CartokMessage>> listMessages(String conversationId, {String? cursor, int limit = 30}) async {
    try {
      final res = await _client.dio.get(
        '/api/v1/messaging/conversations/$conversationId/messages',
        queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
      );
      final items =
          (res.data['data'] as List<dynamic>).map((m) => CartokMessage.fromJson(m as Map<String, dynamic>)).toList();
      return MessagingPage(items: items, nextCursor: res.data['nextCursor'] as String?);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokMessage> sendMessage(String conversationId, String content) async {
    try {
      final res = await _client.dio.post(
        '/api/v1/messaging/conversations/$conversationId/messages',
        data: {'content': content},
      );
      return CartokMessage.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _client.dio.post('/api/v1/messaging/conversations/$conversationId/read');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}
