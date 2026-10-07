import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../auth/repository/auth_repository.dart';
import '../../auth/models/cartok_user.dart';
import '../models/cartok_public_profile.dart';

class FollowPage {
  const FollowPage({required this.items, this.nextCursor});
  final List<CartokFollowUser> items;
  final String? nextCursor;
}

class ProfileRepository {
  ProfileRepository(this._client);

  final ApiClient _client;

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    final message = (data is Map && data['error'] != null)
        ? (data['error']['message'] as String? ?? 'Something went wrong')
        : 'Network error — please check your connection';
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  Future<CartokPublicProfile> getByUsername(String username) async {
    try {
      final res = await _client.dio.get('/api/v1/users/$username');
      return CartokPublicProfile.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> follow(String username) async {
    try {
      await _client.dio.post('/api/v1/users/$username/follow');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> unfollow(String username) async {
    try {
      await _client.dio.delete('/api/v1/users/$username/follow');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<FollowPage> listFollowers(String username, {String? cursor}) async {
    try {
      final res = await _client.dio.get(
        '/api/v1/users/$username/followers',
        queryParameters: {if (cursor != null) 'cursor': cursor},
      );
      final items =
          (res.data['data'] as List<dynamic>).map((u) => CartokFollowUser.fromJson(u as Map<String, dynamic>)).toList();
      return FollowPage(items: items, nextCursor: res.data['nextCursor'] as String?);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<FollowPage> listFollowing(String username, {String? cursor}) async {
    try {
      final res = await _client.dio.get(
        '/api/v1/users/$username/following',
        queryParameters: {if (cursor != null) 'cursor': cursor},
      );
      final items =
          (res.data['data'] as List<dynamic>).map((u) => CartokFollowUser.fromJson(u as Map<String, dynamic>)).toList();
      return FollowPage(items: items, nextCursor: res.data['nextCursor'] as String?);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokUser> updateProfile({String? displayName, String? bio, String? avatarUrl}) async {
    try {
      final res = await _client.dio.patch('/api/v1/users/me', data: {
        if (displayName != null) 'displayName': displayName,
        if (bio != null) 'bio': bio,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      });
      return CartokUser.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}
