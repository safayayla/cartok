// Navigation tests for release-blocker item #4: Home, Garage, Forum,
// Marketplace and Events. Uses the app's REAL appRouterProvider and REAL
// screens (not stand-in placeholder routes) with only the network-backed
// repositories swapped for offline mocks, so this asserts actual
// StatefulShellRoute/bottom-nav wiring, not a reimplementation of it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cartok/app/app_router.dart';
import 'package:cartok/features/discover/screens/home_feed_screen.dart';
import 'package:cartok/features/garage/screens/garage_home_screen.dart';
import 'package:cartok/features/forum/screens/forum_categories_screen.dart';
import 'package:cartok/features/marketplace/screens/marketplace_browse_screen.dart';
import 'package:cartok/features/events/screens/event_list_screen.dart';

import '../helpers/mock_repositories.dart';

class _RouterApp extends ConsumerWidget {
  const _RouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(routerConfig: router);
  }
}

void main() {
  Widget buildApp() => ProviderScope(
        overrides: buildOfflineRepositoryOverrides(),
        child: const _RouterApp(),
      );

  group('Bottom navigation', () {
    testWidgets('an authenticated session lands on the Home feed tab', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(find.byType(HomeFeedScreen), findsOneWidget);
      expect(find.text('For You'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('tapping the Garage tab navigates to GarageHomeScreen', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.garage_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(GarageHomeScreen), findsOneWidget);
      // Signed in as the mocked test user, so the AppBar greets them by
      // first name rather than showing the generic "My garage" title.
      expect(find.text('Hey, Test'), findsOneWidget);
    });

    testWidgets('tapping the Forum tab navigates to ForumCategoriesScreen', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.forum_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(ForumCategoriesScreen), findsOneWidget);
      // Plain find.text('Forum') is ambiguous here: the bottom nav bar's
      // own tab label is also the literal text "Forum" (unlike
      // Marketplace, whose nav label is the shorter "Market"), so a
      // fixed-type BottomNavigationBar showing all labels at once means
      // two matching widgets exist simultaneously. Scope the match to the
      // AppBar title specifically.
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Forum')),
        findsOneWidget,
      );
    });

    testWidgets('tapping the Marketplace tab navigates to MarketplaceBrowseScreen', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.storefront_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(MarketplaceBrowseScreen), findsOneWidget);
      expect(find.text('Marketplace'), findsOneWidget);
    });

    testWidgets('tapping the Events tab navigates to EventListScreen', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.event_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(EventListScreen), findsOneWidget);
      // Same ambiguity as the Forum case above: the bottom nav bar's own
      // "Events" tab label collides with the AppBar title. Scope to the
      // AppBar.
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Events')),
        findsOneWidget,
      );
    });

    testWidgets('each tab keeps its own stack: Garage then Home returns to the feed', (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.garage_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(GarageHomeScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(HomeFeedScreen), findsOneWidget);
      expect(find.byType(GarageHomeScreen), findsNothing);
    });
  });
}
