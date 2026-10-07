import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_token_storage.dart';
import '../repository/auth_repository.dart';

/// Base URL is environment-specific:
///  - Android emulator -> host machine is 10.0.2.2
///  - iOS simulator / physical device on same network -> use your machine's LAN IP
///  - Production -> your deployed API domain
/// Wire this from --dart-define=API_BASE_URL=... in real builds rather than
/// hardcoding, so dev/staging/prod point at different backends.
const _apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:4000',
);

final tokenStorageProvider = Provider<SecureTokenStorage>((ref) => SecureTokenStorage());

/// Resolved once during app startup (see main.dart) before runApp() — not
/// watched reactively from apiClientProvider. Watching it there previously
/// meant the entire client/repository/notifier chain got torn down and
/// rebuilt the moment this Future resolved, firing session-restore twice
/// on every cold start (once with no cookie jar, then again once attached).
final cookieJarProvider = FutureProvider<PersistCookieJar>((ref) {
  return ApiClient.createPersistentCookieJar();
});

/// Constructed exactly once per app run. main.dart awaits the cookie jar
/// and calls attachCookieJar() on this same instance before runApp(), so by
/// the time any widget reads this provider, cookie persistence is already
/// wired up — there is never a "half-initialized" client visible to callers.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: _apiBaseUrl, tokenStorage: ref.watch(tokenStorageProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});
