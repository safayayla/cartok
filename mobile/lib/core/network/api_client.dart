import 'dart:async';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import '../storage/secure_token_storage.dart';

/// Thrown when the refresh flow itself fails — the app should treat this as
/// "session ended" and route back to login, never retry silently forever.
class SessionExpiredException implements Exception {}

/// Central HTTP client. Two responsibilities beyond plain networking:
///  1. Attach the access token to every request.
///  2. On a 401, transparently refresh the access token exactly once and
///     retry the original request — mirroring the backend's rotate-on-use
///     refresh design (see backend/src/modules/auth/auth.service.ts).
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokenStorage}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.readAccessToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        final isAuthRoute = error.requestOptions.path.contains('/auth/');
        if (error.response?.statusCode == 401 && !isAuthRoute) {
          try {
            final newToken = await _refreshAccessToken();
            final retryRequest = error.requestOptions;
            retryRequest.headers['Authorization'] = 'Bearer $newToken';
            final response = await _dio.fetch(retryRequest);
            return handler.resolve(response);
          } catch (_) {
            await tokenStorage.clear();
            return handler.reject(DioException(
              requestOptions: error.requestOptions,
              error: SessionExpiredException(),
              type: DioExceptionType.badResponse,
            ));
          }
        }
        handler.next(error);
      },
    ));
  }

  final String baseUrl;
  final SecureTokenStorage tokenStorage;
  late final Dio _dio;
  Future<String>? _refreshInFlight;

  Dio get dio => _dio;

  /// Must be called once at app startup before any requests are made, so the
  /// httpOnly refresh cookie persists across app restarts (a fresh CookieJar
  /// per launch would silently log every user out on every cold start).
  static Future<PersistCookieJar> createPersistentCookieJar() async {
    final dir = await getApplicationDocumentsDirectory();
    return PersistCookieJar(storage: FileStorage('${dir.path}/.cookies/'));
  }

  void attachCookieJar(PersistCookieJar jar) {
    _dio.interceptors.insert(0, CookieManager(jar));
  }

  // Coalesces concurrent refresh attempts: if five requests 401 at once, we
  // want exactly one refresh call, not five racing to rotate the same token.
  Future<String> _refreshAccessToken() {
    _refreshInFlight ??= _doRefresh().whenComplete(() => _refreshInFlight = null);
    return _refreshInFlight!;
  }

  Future<String> _doRefresh() async {
    final response = await _dio.post('/api/v1/auth/refresh');
    final newToken = response.data['data']['accessToken'] as String;
    await tokenStorage.saveAccessToken(newToken);
    return newToken;
  }
}
