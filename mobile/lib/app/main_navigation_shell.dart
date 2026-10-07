import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/cartok_colors.dart';
import '../features/notifications/providers/notifications_providers.dart';

/// The persistent bottom nav bar wrapping each top-level section. Using
/// StatefulShellRoute means each tab keeps its own navigation stack and
/// scroll position when switching away and back — tapping "Garage" after
/// browsing three levels deep into "Forum" returns to Forum exactly where
/// you left it, not back to its root.
class MainNavigationShell extends ConsumerWidget {
  const MainNavigationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the already-active tab resets it to its root route instead
      // of doing nothing — the common, expected bottom-nav behavior.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.garage_rounded), label: 'Garage'),
          const BottomNavigationBarItem(icon: Icon(Icons.forum_rounded), label: 'Forum'),
          const BottomNavigationBarItem(icon: Icon(Icons.storefront_rounded), label: 'Market'),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
              backgroundColor: CartokColors.redline,
              child: const Icon(Icons.notifications_rounded),
            ),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.event_rounded), label: 'Events'),
        ],
      ),
    );
  }
}
