import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../auth/repository/auth_repository.dart';
import '../models/cartok_listing.dart';

class ListingPage {
  const ListingPage({required this.items, this.nextCursor});
  final List<CartokListing> items;
  final String? nextCursor;
}

class MarketplaceRepository {
  MarketplaceRepository(this._client);

  final ApiClient _client;

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    final message = (data is Map && data['error'] != null)
        ? (data['error']['message'] as String? ?? 'Something went wrong')
        : 'Network error — please check your connection';
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  Future<ListingPage> list({
    String? type,
    int? minPriceCents,
    int? maxPriceCents,
    String? search,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final res = await _client.dio.get('/api/v1/marketplace', queryParameters: {
        if (type != null) 'type': type,
        if (minPriceCents != null) 'minPriceCents': minPriceCents,
        if (maxPriceCents != null) 'maxPriceCents': maxPriceCents,
        if (search != null && search.isNotEmpty) 'search': search,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      });
      final items =
          (res.data['data'] as List<dynamic>).map((l) => CartokListing.fromJson(l as Map<String, dynamic>)).toList();
      return ListingPage(items: items, nextCursor: res.data['nextCursor'] as String?);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<ListingPage> mine() async {
    try {
      final res = await _client.dio.get('/api/v1/marketplace/mine');
      final items =
          (res.data['data'] as List<dynamic>).map((l) => CartokListing.fromJson(l as Map<String, dynamic>)).toList();
      return ListingPage(items: items, nextCursor: res.data['nextCursor'] as String?);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<ListingPage> favorites() async {
    try {
      final res = await _client.dio.get('/api/v1/marketplace/favorites');
      final items =
          (res.data['data'] as List<dynamic>).map((l) => CartokListing.fromJson(l as Map<String, dynamic>)).toList();
      return ListingPage(items: items, nextCursor: res.data['nextCursor'] as String?);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokListing> getById(String listingId) async {
    try {
      final res = await _client.dio.get('/api/v1/marketplace/$listingId');
      return CartokListing.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokListing> create({
    required String type,
    required String title,
    required String description,
    required int priceCents,
    String? condition,
    String? location,
    String? vehicleId,
    List<String> imageUrls = const [],
  }) async {
    try {
      final res = await _client.dio.post('/api/v1/marketplace', data: {
        'type': type,
        'title': title,
        'description': description,
        'priceCents': priceCents,
        if (condition != null) 'condition': condition,
        if (location != null && location.isNotEmpty) 'location': location,
        if (vehicleId != null) 'vehicleId': vehicleId,
        'imageUrls': imageUrls,
      });
      return CartokListing.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> updateStatus(String listingId, String status) async {
    try {
      await _client.dio.patch('/api/v1/marketplace/$listingId/status', data: {'status': status});
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> favorite(String listingId) async {
    try {
      await _client.dio.post('/api/v1/marketplace/$listingId/favorite');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> unfavorite(String listingId) async {
    try {
      await _client.dio.delete('/api/v1/marketplace/$listingId/favorite');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}
