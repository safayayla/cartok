import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_dependencies_provider.dart';
import '../models/cartok_public_profile.dart';
import '../repository/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

class ProfileState {
  const ProfileState({this.profile, this.isLoading = true, this.error});

  final CartokPublicProfile? profile;
  final bool isLoading;
  final Object? error;

  ProfileState copyWith({CartokPublicProfile? profile, bool? isLoading, Object? error, bool clearError = false}) =>
      ProfileState(
        profile: profile ?? this.profile,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier(this._repository, this._username) : super(const ProfileState()) {
    load();
  }

  final ProfileRepository _repository;
  final String _username;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repository.getByUsername(_username);
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Optimistic: the button and follower count flip immediately, before the
  /// network call resolves, and roll back only if it actually fails —
  /// consistent with how voting works in the forum feature.
  Future<void> toggleFollow() async {
    final profile = state.profile;
    if (profile == null) return;

    final wasFollowing = profile.isFollowedByMe;
    final optimistic = profile.copyWith(
      isFollowedByMe: !wasFollowing,
      followerCount: profile.followerCount + (wasFollowing ? -1 : 1),
    );
    state = state.copyWith(profile: optimistic);

    try {
      if (wasFollowing) {
        await _repository.unfollow(_username);
      } else {
        await _repository.follow(_username);
      }
    } catch (e) {
      state = state.copyWith(profile: profile); // revert to the exact pre-toggle state
      rethrow;
    }
  }
}

final profileProvider = StateNotifierProvider.family<ProfileNotifier, ProfileState, String>((ref, username) {
  return ProfileNotifier(ref.watch(profileRepositoryProvider), username);
});
