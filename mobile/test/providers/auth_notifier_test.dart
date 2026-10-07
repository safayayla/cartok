// Meaningful provider/repository test (release-blocker item #4): exercises
// AuthNotifier's real state-machine logic against a mocked AuthRepository,
// asserting actual state transitions rather than just "it builds."
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cartok/features/auth/models/cartok_user.dart';
import 'package:cartok/features/auth/providers/auth_notifier.dart';
import 'package:cartok/features/auth/repository/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _user = CartokUser(
  id: 'user-1',
  email: 'driver@cartok.app',
  username: 'driver',
  displayName: 'Driver One',
  verification: 'VERIFIED',
);

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    // Every AuthNotifier is constructed with a call to _restoreSession(),
    // which calls fetchMe() once up front. Default it to "not signed in"
    // so each test starts from a known, deterministic unauthenticated
    // state before exercising login/register.
    when(() => repository.fetchMe()).thenAnswer((_) async => _user);
  });

  group('AuthNotifier', () {
    test('starts in checking state and settles to authenticated when a session exists', () async {
      final notifier = AuthNotifier(repository);

      expect(notifier.state.status, AuthStatus.checking);

      // _restoreSession's fetchMe() call is in flight; let it resolve.
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.user?.username, 'driver');
    });

    test('settles to unauthenticated when no session exists', () async {
      when(() => repository.fetchMe()).thenThrow(ApiException('Unauthorized', statusCode: 401));

      final notifier = AuthNotifier(repository);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state.status, AuthStatus.unauthenticated);
    });

    test('login() on success authenticates and stores the returned user', () async {
      when(() => repository.fetchMe()).thenThrow(ApiException('Unauthorized', statusCode: 401));
      final notifier = AuthNotifier(repository);
      await Future<void>.delayed(Duration.zero);

      when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => 'access-token');
      when(() => repository.fetchMe()).thenAnswer((_) async => _user);

      final result = await notifier.login(email: 'driver@cartok.app', password: 'Str0ngPassw0rd');

      expect(result, isTrue);
      expect(notifier.state.status, AuthStatus.authenticated);
      expect(notifier.state.user, isNotNull);
      expect(notifier.state.user!.id, 'user-1');
      expect(notifier.state.errorMessage, isNull);
    });

    test('login() on failure stays unauthenticated and surfaces the error message', () async {
      when(() => repository.fetchMe()).thenThrow(ApiException('Unauthorized', statusCode: 401));
      final notifier = AuthNotifier(repository);
      await Future<void>.delayed(Duration.zero);

      when(() => repository.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(ApiException('Invalid email or password', statusCode: 401));

      final result = await notifier.login(email: 'driver@cartok.app', password: 'wrong');

      expect(result, isFalse);
      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.user, isNull);
      expect(notifier.state.errorMessage, contains('Invalid email or password'));
    });

    test('logout() clears the authenticated user and returns to unauthenticated', () async {
      final notifier = AuthNotifier(repository);
      await Future<void>.delayed(Duration.zero);
      expect(notifier.state.status, AuthStatus.authenticated);

      when(() => repository.logout()).thenAnswer((_) async {});

      await notifier.logout();

      expect(notifier.state.status, AuthStatus.unauthenticated);
      expect(notifier.state.user, isNull);
      verify(() => repository.logout()).called(1);
    });
  });
}
