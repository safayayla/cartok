// Login screen rendering test (release-blocker item #4).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cartok/features/auth/screens/login_screen.dart';

void main() {
  Widget wrap(Widget child) {
    return ProviderScope(
      child: MaterialApp(home: child),
    );
  }

  group('LoginScreen', () {
    testWidgets('renders the sign-in form with email, password and submit button', (tester) async {
      await tester.pumpWidget(wrap(const LoginScreen()));

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign in'), findsOneWidget);
      expect(find.text("Don't have an account? Create one"), findsOneWidget);
    });

    testWidgets('password field starts obscured and reveals on toggle', (tester) async {
      await tester.pumpWidget(wrap(const LoginScreen()));

      TextField passwordField() => tester.widget<TextField>(
            find.descendant(
              of: find.widgetWithText(TextFormField, 'Password'),
              matching: find.byType(TextField),
            ),
          );

      expect(passwordField().obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(passwordField().obscureText, isFalse);
    });

    testWidgets('shows validation errors when submitting empty fields', (tester) async {
      await tester.pumpWidget(wrap(const LoginScreen()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('shows an email-format error for a value without "@"', (tester) async {
      await tester.pumpWidget(wrap(const LoginScreen()));

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'not-an-email');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });
  });
}
