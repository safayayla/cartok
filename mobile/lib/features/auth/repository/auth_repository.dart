import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/cartok_user.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    final message = (data is Map && data['error'] != null)
        ? (data['error']['message'] as String? ?? 'Something went wrong')
        : 'Network error — please check your connection';
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  Future<CartokUser> register({
    required String email,
    required String username,
    required String password,
    required String displayName,
  }) async {
    try {
      final res = await _client.dio.post('/api/v1/auth/register', data: {
        'email': email,
        'username': username,
        'password': password,
        'displayName': displayName,
      });
      return CartokUser.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Returns the access token; the refresh token arrives as an httpOnly
  /// cookie the CookieManager interceptor stores automatically.
  Future<String> login({required String email, required String password}) async {
    try {
      final res = await _client.dio.post('/api/v1/auth/login', data: {
        'email': email,
        'password': password,
      });
      final token = res.data['data']['accessToken'] as String;
      await _client.tokenStorage.saveAccessToken(token);
      return token;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokUser> fetchMe() async {
    try {
      final res = await _client.dio.get('/api/v1/users/me');
      return CartokUser.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _client.dio.post('/api/v1/auth/logout');
    } on DioException {
      // Logout should succeed locally even if the network call fails —
      // we still clear the local token below.
    } finally {
      await _client.tokenStorage.clear();
    }
  }
}
