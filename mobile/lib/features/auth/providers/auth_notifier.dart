import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cartok_user.dart';
import '../repository/auth_repository.dart';
import 'auth_dependencies_provider.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.user, this.errorMessage});

  final AuthStatus status;
  final CartokUser? user;
  final String? errorMessage;

  AuthState copyWith({AuthStatus? status, CartokUser? user, String? errorMessage}) => AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        errorMessage: errorMessage,
      );

  static const checking = AuthState(status: AuthStatus.checking);
  static const unauthenticated = AuthState(status: AuthStatus.unauthenticated);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository) : super(AuthState.checking) {
    _restoreSession();
  }

  final AuthRepository _repository;

  /// Called once on app start. A stored access token might be expired, so we
  /// don't trust it blindly — we validate it by calling /users/me, and let
  /// the ApiClient's interceptor transparently refresh it if that 401s.
  Future<void> _restoreSession() async {
    try {
      final user = await _repository.fetchMe();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      state = AuthState.unauthenticated;
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.checking, errorMessage: null);
    try {
      await _repository.login(email: email, password: password);
      final user = await _repository.fetchMe();
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(status: AuthStatus.checking, errorMessage: null);
    try {
      await _repository.register(
        email: email,
        username: username,
        password: password,
        displayName: displayName,
      );
      // Registration succeeded — log in immediately for a seamless first run.
      return login(email: email, password: password);
    } catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = AuthState.unauthenticated;
  }

  /// Re-fetches the current user record without touching auth status —
  /// used after editing the profile so the new displayName/bio show up
  /// everywhere the cached user is read from, without a full re-login.
  /// Failures here are silent and non-fatal: the previously displayed data
  /// just stays as-is until the next successful refresh.
  Future<void> refreshCurrentUser() async {
    try {
      final user = await _repository.fetchMe();
      state = state.copyWith(user: user);
    } catch (_) {
      // Intentionally ignored — see doc comment above.
    }
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
