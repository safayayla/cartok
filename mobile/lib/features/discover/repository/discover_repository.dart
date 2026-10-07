import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../auth/repository/auth_repository.dart';
import '../models/cartok_feed_item.dart';

class DiscoverRepository {
  DiscoverRepository(this._client);

  final ApiClient _client;

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    final message = (data is Map && data['error'] != null)
        ? (data['error']['message'] as String? ?? 'Something went wrong')
        : 'Network error — please check your connection';
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  /// Note: the backend feed endpoint is deliberately unpaginated today (see
  /// discover.service.ts's own doc comment on why) — it returns a single
  /// bounded, freshly-scored batch rather than a cursor stream. Pull-to-refresh
  /// re-fetches; there is no "load more" here yet.
  Future<List<CartokFeedItem>> getFeed({int limit = 20}) async {
    try {
      final res = await _client.dio.get('/api/v1/discover', queryParameters: {'limit': limit});
      final raw = res.data['data'] as List<dynamic>;
      final items = <CartokFeedItem>[];
      for (final entry in raw) {
        try {
          items.add(CartokFeedItem.fromJson(entry as Map<String, dynamic>));
        } on FormatException {
          // Skip items of a type this client version doesn't know about
          // yet, rather than failing the entire feed over one entry.
          continue;
        }
      }
      return items;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}
