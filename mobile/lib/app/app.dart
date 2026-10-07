import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/cartok_theme.dart';
import 'app_router.dart';

class CartokApp extends ConsumerWidget {
  const CartokApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Cartok',
      debugShowCheckedModeBanner: false,
      theme: CartokTheme.dark,
      darkTheme: CartokTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
