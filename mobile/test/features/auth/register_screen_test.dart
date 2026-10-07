// Register screen validation test (release-blocker item #4).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cartok/features/auth/repository/auth_repository.dart';
import 'package:cartok/features/auth/providers/auth_dependencies_provider.dart';
import 'package:cartok/features/auth/screens/register_screen.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  // RegisterScreen's AppBar back button calls context.go('/login'), so it
  // needs a router in the tree even though these tests never navigate away.
  // authRepositoryProvider is always overridden with a mock that never hits
  // the network — a submit that passes validation would otherwise fire a
  // real Dio request to a backend that doesn't exist in this test process.
  Widget wrap(Widget child) {
    final router = GoRouter(
      initialLocation: '/register',
      routes: [
        GoRoute(path: '/register', builder: (context, state) => child),
        GoRoute(path: '/login', builder: (context, state) => const Scaffold(body: Text('Login'))),
      ],
    );
    final mockAuthRepo = _MockAuthRepository();
    when(() => mockAuthRepo.register(
          email: any(named: 'email'),
          username: any(named: 'username'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
        )).thenThrow(ApiException('unreachable in tests'));

    return ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(mockAuthRepo)],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  group('RegisterScreen validation', () {
    testWidgets('rejects an empty form with one error per required field', (tester) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pump();

      expect(find.text('Enter a display name'), findsOneWidget);
      expect(find.text('Enter a username'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('At least 10 characters'), findsOneWidget);
    });

    testWidgets('rejects a username with uppercase letters or symbols', (tester) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'Not-Valid!');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pump();

      expect(find.text('Lowercase letters, numbers, _ and . only'), findsOneWidget);
    });

    testWidgets('rejects an email without "@"', (tester) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'nope');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('rejects a password missing a number or mixed case', (tester) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'alllowercase');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pump();

      expect(find.text('Needs upper and lowercase letters'), findsOneWidget);
    });

    testWidgets('accepts a fully valid form with no validation errors shown', (tester) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Display name'), 'Jamie Driver');
      await tester.enterText(find.widgetWithText(TextFormField, 'Username'), 'jamie_d');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'jamie@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'Str0ngPassw0rd');

      // Submitting will attempt a real network call via the default
      // ProviderScope's authNotifierProvider; validation passing (no error
      // text) is what this test asserts, not the network outcome.
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pump();

      expect(find.text('Enter a display name'), findsNothing);
      expect(find.text('Enter a username'), findsNothing);
      expect(find.text('Lowercase letters, numbers, _ and . only'), findsNothing);
      expect(find.text('Enter a valid email'), findsNothing);
      expect(find.text('At least 10 characters'), findsNothing);
      expect(find.text('Needs upper and lowercase letters'), findsNothing);
      expect(find.text('Needs a number'), findsNothing);
    });
  });
}
