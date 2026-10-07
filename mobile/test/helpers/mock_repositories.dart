// Shared mocktail doubles for every repository the widget/navigation tests
// touch, plus a convenience ProviderScope override list.
//
// Every screen in this app resolves its data through a Riverpod provider
// that ultimately depends on `apiClientProvider`, which talks to a real
// backend over Dio. Widget tests must never make real network calls (no
// server exists in the test environment, and a pending request leaves a
// dangling timer that fails `flutter test`'s "all timers disposed" check).
// Mocking each repository at the Provider boundary — rather than mocking
// Dio itself — keeps these tests fast, deterministic, and focused on real
// widget/navigation behavior instead of HTTP plumbing.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cartok/features/auth/models/cartok_user.dart';
import 'package:cartok/features/auth/repository/auth_repository.dart';
import 'package:cartok/features/auth/providers/auth_dependencies_provider.dart';
import 'package:cartok/features/garage/repository/garage_repository.dart';
import 'package:cartok/features/garage/providers/garage_providers.dart';
import 'package:cartok/features/forum/repository/forum_repository.dart';
import 'package:cartok/features/forum/providers/forum_providers.dart';
import 'package:cartok/features/discover/repository/discover_repository.dart';
import 'package:cartok/features/discover/providers/discover_providers.dart';
import 'package:cartok/features/events/repository/events_repository.dart';
import 'package:cartok/features/events/providers/event_list_provider.dart';
import 'package:cartok/features/messaging/repository/messaging_repository.dart';
import 'package:cartok/features/messaging/providers/conversation_list_provider.dart';
import 'package:cartok/features/marketplace/repository/marketplace_repository.dart';
import 'package:cartok/features/marketplace/providers/marketplace_providers.dart';
import 'package:cartok/features/notifications/repository/notifications_repository.dart';
import 'package:cartok/features/notifications/providers/notifications_providers.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockGarageRepository extends Mock implements GarageRepository {}

class MockForumRepository extends Mock implements ForumRepository {}

class MockDiscoverRepository extends Mock implements DiscoverRepository {}

class MockEventsRepository extends Mock implements EventsRepository {}

class MockMessagingRepository extends Mock implements MessagingRepository {}

class MockMarketplaceRepository extends Mock implements MarketplaceRepository {}

class MockNotificationsRepository extends Mock implements NotificationsRepository {}

const testUser = CartokUser(
  id: 'test-user-1',
  email: 'driver@cartok.app',
  username: 'driver',
  displayName: 'Test Driver',
  verification: 'VERIFIED',
);

/// Builds the full set of provider overrides needed so every screen in the
/// app (bottom-nav tabs + messaging) can build without touching the network.
/// Each repository is stubbed with the minimal "empty but successful"
/// response its screen needs to reach its empty state rather than hang on
/// a never-completing future or a real socket error.
///
/// [authenticated] controls whether the mocked session starts signed in.
/// Navigation tests need `true` — `appRouterProvider`'s redirect sends an
/// unauthenticated session straight to `/login`, which would make every
/// other route unreachable.
List<Override> buildOfflineRepositoryOverrides({bool authenticated = true}) {
  final authRepo = MockAuthRepository();
  if (authenticated) {
    when(() => authRepo.fetchMe()).thenAnswer((_) async => testUser);
  } else {
    when(() => authRepo.fetchMe()).thenThrow(ApiException('Not signed in', statusCode: 401));
  }

  final garageRepo = MockGarageRepository();
  when(() => garageRepo.myGarages()).thenAnswer((_) async => []);

  final forumRepo = MockForumRepository();
  when(() => forumRepo.listCategories()).thenAnswer((_) async => []);

  final discoverRepo = MockDiscoverRepository();
  when(() => discoverRepo.getFeed()).thenAnswer((_) async => []);

  // EventListNotifier's and ListingBrowseNotifier's _load() both pass their
  // filter fields as explicit named arguments (even when null), so the
  // stub is registered for that exact named-argument shape — matching the
  // real initial-load call site, which this test suite's navigation tests
  // exercise. (Their loadMore()/pagination call sites add a `cursor` and
  // are not covered here, since no test drives pagination.)
  final eventsRepo = MockEventsRepository();
  when(() => eventsRepo.list(type: any(named: 'type')))
      .thenAnswer((_) async => const EventPage(items: []));

  final messagingRepo = MockMessagingRepository();
  when(() => messagingRepo.listConversations())
      .thenAnswer((_) async => const MessagingPage(items: []));

  final marketplaceRepo = MockMarketplaceRepository();
  when(() => marketplaceRepo.list(
        type: any(named: 'type'),
        minPriceCents: any(named: 'minPriceCents'),
        maxPriceCents: any(named: 'maxPriceCents'),
        search: any(named: 'search'),
      )).thenAnswer((_) async => const ListingPage(items: []));

  final notificationsRepo = MockNotificationsRepository();
  when(() => notificationsRepo.unreadCount()).thenAnswer((_) async => 0);

  return [
    authRepositoryProvider.overrideWithValue(authRepo),
    garageRepositoryProvider.overrideWithValue(garageRepo),
    forumRepositoryProvider.overrideWithValue(forumRepo),
    discoverRepositoryProvider.overrideWithValue(discoverRepo),
    eventsRepositoryProvider.overrideWithValue(eventsRepo),
    messagingRepositoryProvider.overrideWithValue(messagingRepo),
    marketplaceRepositoryProvider.overrideWithValue(marketplaceRepo),
    notificationsRepositoryProvider.overrideWithValue(notificationsRepo),
  ];
}
