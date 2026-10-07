import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'features/auth/providers/auth_dependencies_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resolve the persistent cookie jar and attach it to the one-and-only
  // ApiClient instance *before* any provider or widget can observe an
  // unattached client. Doing this here (imperatively, once) rather than via
  // a reactive ref.watch inside apiClientProvider avoids ever constructing a
  // second client mid-flight — see auth_dependencies_provider.dart.
  final container = ProviderContainer();
  final cookieJar = await container.read(cookieJarProvider.future);
  container.read(apiClientProvider).attachCookieJar(cookieJar);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CartokApp(),
    ),
  );
}
