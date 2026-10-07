import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_notifier.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/garage/screens/add_vehicle_screen.dart';
import '../features/garage/screens/garage_home_screen.dart';
import '../features/garage/screens/vehicle_detail_screen.dart';
import '../features/garage/screens/public_garage_detail_screen.dart';
import '../features/forum/screens/forum_categories_screen.dart';
import '../features/forum/screens/thread_list_screen.dart';
import '../features/forum/screens/thread_detail_screen.dart';
import '../features/marketplace/screens/marketplace_browse_screen.dart';
import '../features/marketplace/screens/listing_detail_screen.dart';
import '../features/marketplace/screens/create_listing_screen.dart';
import '../features/marketplace/screens/favorites_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/profile/screens/follow_list_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/bookmarks_screen.dart';
import '../features/events/screens/event_list_screen.dart';
import '../features/events/screens/event_detail_screen.dart';
import '../features/events/screens/create_event_screen.dart';
import '../features/search/screens/search_screen.dart';
import '../features/discover/screens/home_feed_screen.dart';
import '../features/messaging/screens/conversation_list_screen.dart';
import '../features/messaging/screens/chat_thread_screen.dart';
import 'main_navigation_shell.dart';

/// Small ChangeNotifier bridge so GoRouter's `refreshListenable` reacts to
/// Riverpod auth-state changes (GoRouter doesn't know about Riverpod
/// providers natively, so this adapter is the standard bridge pattern).
class _AuthRouterRefresh extends ChangeNotifier {
  _AuthRouterRefresh(Ref ref) {
    ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRouterRefresh(ref);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (authState.status == AuthStatus.checking) return null; // stay on splash

      if (authState.status == AuthStatus.unauthenticated && !loggingIn) return '/login';
      if (authState.status == AuthStatus.authenticated && (loggingIn || state.matchedLocation == '/')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainNavigationShell(navigationShell: navigationShell),
        branches: [
          // Branch 0: Home (discover feed) - the landing tab
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (context, state) => const HomeFeedScreen()),
            ],
          ),
          // Branch 1: Garage tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/garage',
                builder: (context, state) => const GarageHomeScreen(),
                routes: [
                  GoRoute(
                    path: 'add-vehicle/:garageId',
                    builder: (context, state) =>
                        AddVehicleScreen(garageId: state.pathParameters['garageId']!),
                  ),
                  GoRoute(
                    path: 'vehicle/:garageId/:vehicleId',
                    builder: (context, state) => VehicleDetailScreen(
                      garageId: state.pathParameters['garageId']!,
                      vehicleId: state.pathParameters['vehicleId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'detail/:garageId',
                    builder: (context, state) =>
                        PublicGarageDetailScreen(garageId: state.pathParameters['garageId']!),
                  ),
                ],
              ),
            ],
          ),
          // Branch 2: Forum tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/forum',
                builder: (context, state) => const ForumCategoriesScreen(),
                routes: [
                  GoRoute(
                    path: ':categoryId',
                    builder: (context, state) => ThreadListScreen(
                      categoryId: state.pathParameters['categoryId']!,
                      categoryName: (state.extra as String?) ?? 'Forum',
                    ),
                  ),
                  GoRoute(
                    path: 'thread/:threadId',
                    builder: (context, state) =>
                        ThreadDetailScreen(threadId: state.pathParameters['threadId']!),
                  ),
                ],
              ),
            ],
          ),
          // Branch 3: Marketplace tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/marketplace',
                builder: (context, state) => const MarketplaceBrowseScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const CreateListingScreen(),
                  ),
                  GoRoute(
                    path: 'favorites',
                    builder: (context, state) => const FavoritesScreen(),
                  ),
                  GoRoute(
                    path: ':listingId',
                    builder: (context, state) =>
                        ListingDetailScreen(listingId: state.pathParameters['listingId']!),
                  ),
                ],
              ),
            ],
          ),
          // Branch 4: Notifications tab ("Alerts")
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
            ],
          ),
          // Branch 5: Events tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/events',
                builder: (context, state) => const EventListScreen(),
                routes: [
                  GoRoute(path: 'new', builder: (context, state) => const CreateEventScreen()),
                  GoRoute(
                    path: ':eventId',
                    builder: (context, state) => EventDetailScreen(eventId: state.pathParameters['eventId']!),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),

      GoRoute(
        path: '/messages',
        builder: (context, state) => const ConversationListScreen(),
      ),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (context, state) => ChatThreadScreen(
          conversationId: state.pathParameters['conversationId']!,
          otherDisplayName: state.extra as String?,
        ),
      ),

      // Profile routes are reachable from many places (garage owner avatar,
      // forum post author, marketplace seller, follow lists) rather than
      // belonging to one tab, so they're top-level pushed routes rather
      // than nested under a single branch.
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/bookmarks',
        builder: (context, state) => const BookmarksScreen(),
      ),
      GoRoute(
        path: '/profile/:username',
        builder: (context, state) => ProfileScreen(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: '/profile/:username/followers',
        builder: (context, state) => FollowListScreen(
          username: state.pathParameters['username']!,
          mode: FollowListMode.followers,
        ),
      ),
      GoRoute(
        path: '/profile/:username/following',
        builder: (context, state) => FollowListScreen(
          username: state.pathParameters['username']!,
          mode: FollowListMode.following,
        ),
      ),
    ],
  );

  // Without this, both the GoRouter and the ChangeNotifier's underlying
  // ref.listen subscription to authNotifierProvider outlive the provider
  // itself — harmless for one long-lived container in production, but a
  // real leak across hot-reloads and a source of cross-test state bleed.
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });

  return router;
});
