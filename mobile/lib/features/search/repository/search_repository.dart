import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../auth/repository/auth_repository.dart';
import '../../garage/models/cartok_garage.dart';
import '../../profile/models/cartok_public_profile.dart';

/// Composes search across the garage, user, and marketplace endpoints
/// rather than introducing a new backend aggregation module — each of
/// those already supports its own search query, so the client fans out to
/// all three (marketplace's existing repository is reused directly by the
/// search screen for its tab). A real cross-entity search with relevance
/// ranking across types would want Postgres full-text search or a
/// dedicated search index; this is the honest, bounded version until
/// that's justified.
class SearchRepository {
  SearchRepository(this._client);

  final ApiClient _client;

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    final message = (data is Map && data['error'] != null)
        ? (data['error']['message'] as String? ?? 'Something went wrong')
        : 'Network error — please check your connection';
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  Future<List<CartokGarage>> searchGarages(String query) async {
    try {
      final res = await _client.dio.get('/api/v1/garages', queryParameters: {'search': query, 'limit': 20});
      return (res.data['data'] as List<dynamic>).map((g) => CartokGarage.fromJson(g as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<CartokFollowUser>> searchUsers(String query) async {
    try {
      final res = await _client.dio.get('/api/v1/users/search', queryParameters: {'q': query, 'limit': 20});
      return (res.data['data'] as List<dynamic>)
          .map((u) => CartokFollowUser.fromJson(u as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}
