import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cartok_garage.dart';
import '../repository/garage_repository.dart';
import 'garage_providers.dart';

class PublicGarageState {
  const PublicGarageState({this.garage, this.isLoading = true, this.error});

  final CartokGarage? garage;
  final bool isLoading;
  final Object? error;

  PublicGarageState copyWith({CartokGarage? garage, bool? isLoading, Object? error, bool clearError = false}) =>
      PublicGarageState(
        garage: garage ?? this.garage,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class PublicGarageNotifier extends StateNotifier<PublicGarageState> {
  PublicGarageNotifier(this._repository, this._garageId) : super(const PublicGarageState()) {
    load();
  }

  final GarageRepository _repository;
  final String _garageId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final garage = await _repository.getGarage(_garageId);
      state = state.copyWith(garage: garage, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Optimistic, same pattern as forum voting and profile follow: the
  /// button and follower count flip instantly, and roll back only if the
  /// network call actually fails.
  Future<void> toggleFollow() async {
    final garage = state.garage;
    if (garage == null) return;

    final wasFollowing = garage.isFollowedByMe;
    final optimistic = garage.copyWith(
      isFollowedByMe: !wasFollowing,
      followerCount: garage.followerCount + (wasFollowing ? -1 : 1),
    );
    state = state.copyWith(garage: optimistic);

    try {
      if (wasFollowing) {
        await _repository.unfollowGarage(_garageId);
      } else {
        await _repository.followGarage(_garageId);
      }
    } catch (e) {
      state = state.copyWith(garage: garage);
      rethrow;
    }
  }
}

final publicGarageProvider =
    StateNotifierProvider.family<PublicGarageNotifier, PublicGarageState, String>((ref, garageId) {
  return PublicGarageNotifier(ref.watch(garageRepositoryProvider), garageId);
});
