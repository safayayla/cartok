import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_dependencies_provider.dart';
import '../repository/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

/// Watched by the nav shell to show a badge on the notifications tab.
/// Invalidated (not polled) after actions that change it — marking read,
/// or a full list refresh — rather than running a timer, since there's no
/// push/websocket channel yet to tell the client when a new notification
/// actually arrives (see ARCHITECTURE.md's "not yet implemented" list).
final unreadNotificationCountProvider = FutureProvider<int>((ref) {
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});
