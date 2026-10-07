import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps flutter_secure_storage (iOS Keychain / Android EncryptedSharedPreferences)
/// so tokens are never touched via SharedPreferences/plain storage.
class SecureTokenStorage {
  SecureTokenStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
        );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'cartok_access_token';

  Future<void> saveAccessToken(String token) => _storage.write(key: _accessTokenKey, value: token);

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<void> clear() => _storage.delete(key: _accessTokenKey);

  // Note: the refresh token itself is never held here — it lives only in the
  // backend's httpOnly, Secure, SameSite=Strict cookie, so it's inaccessible
  // to app-side JS/code entirely and is sent automatically by the HTTP client's
  // cookie jar. This mirrors the backend's design (see auth.controller.ts).
}
