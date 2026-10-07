// Navigation test for release-blocker item #4: Messaging. Messaging is a
// top-level pushed route (not a bottom-nav tab - see app_router.dart),
// reachable from the Home feed's mail icon, so it's verified as a push
// navigation from there rather than a tab tap.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cartok/app/app_router.dart';
import 'package:cartok/features/discover/screens/home_feed_screen.dart';
import 'package:cartok/features/messaging/screens/conversation_list_screen.dart';

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
  testWidgets('tapping the mail icon on Home pushes the conversation list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: buildOfflineRepositoryOverrides(),
        child: const _RouterApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeFeedScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mail_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(ConversationListScreen), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);

    // It's a push, not a tab swap - the back arrow returns to Home.
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(HomeFeedScreen), findsOneWidget);
  });
}
