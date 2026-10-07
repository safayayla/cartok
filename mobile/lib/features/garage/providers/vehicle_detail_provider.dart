import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cartok_vehicle.dart';
import '../models/cartok_vehicle_comment.dart';
import '../repository/garage_repository.dart';
import 'garage_providers.dart';

class VehicleDetailState {
  const VehicleDetailState({
    this.vehicle,
    this.comments = const [],
    this.isLoading = true,
    this.isLoadingComments = false,
    this.error,
  });

  final CartokVehicle? vehicle;
  final List<CartokVehicleComment> comments;
  final bool isLoading;
  final bool isLoadingComments;
  final Object? error;

  VehicleDetailState copyWith({
    CartokVehicle? vehicle,
    List<CartokVehicleComment>? comments,
    bool? isLoading,
    bool? isLoadingComments,
    Object? error,
    bool clearError = false,
  }) =>
      VehicleDetailState(
        vehicle: vehicle ?? this.vehicle,
        comments: comments ?? this.comments,
        isLoading: isLoading ?? this.isLoading,
        isLoadingComments: isLoadingComments ?? this.isLoadingComments,
        error: clearError ? null : (error ?? this.error),
      );
}

class VehicleDetailNotifier extends StateNotifier<VehicleDetailState> {
  VehicleDetailNotifier(this._repository, this._garageId, this._vehicleId) : super(const VehicleDetailState()) {
    load();
  }

  final GarageRepository _repository;
  final String _garageId;
  final String _vehicleId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final vehicle = await _repository.getVehicle(garageId: _garageId, vehicleId: _vehicleId);
      state = state.copyWith(vehicle: vehicle, isLoading: false);
      // Comments load right after — kept as a separate, independently
      // retryable step rather than blocking the whole screen on both
      // requests succeeding together.
      unawaited(loadComments());
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadComments() async {
    state = state.copyWith(isLoadingComments: true);
    try {
      final comments = await _repository.listVehicleComments(garageId: _garageId, vehicleId: _vehicleId);
      state = state.copyWith(comments: comments, isLoadingComments: false);
    } catch (_) {
      // Comments failing to load shouldn't take down the whole vehicle
      // detail view — the vehicle info above is still shown either way.
      state = state.copyWith(isLoadingComments: false);
    }
  }

  /// Optimistic — same pattern used throughout this app (forum voting,
  /// profile/garage follow): flips instantly, rolls back only on failure.
  Future<void> toggleLike() async {
    final vehicle = state.vehicle;
    if (vehicle == null) return;

    final wasLiked = vehicle.isLikedByMe;
    final optimistic = vehicle.copyWith(
      isLikedByMe: !wasLiked,
      likeCount: vehicle.likeCount + (wasLiked ? -1 : 1),
    );
    state = state.copyWith(vehicle: optimistic);

    try {
      if (wasLiked) {
        await _repository.unlikeVehicle(garageId: _garageId, vehicleId: _vehicleId);
      } else {
        await _repository.likeVehicle(garageId: _garageId, vehicleId: _vehicleId);
      }
    } catch (e) {
      state = state.copyWith(vehicle: vehicle);
      rethrow;
    }
  }

  /// Optimistic, same reasoning as toggleLike above.
  Future<void> toggleBookmark() async {
    final vehicle = state.vehicle;
    if (vehicle == null) return;

    final wasBookmarked = vehicle.isBookmarkedByMe;
    state = state.copyWith(vehicle: vehicle.copyWith(isBookmarkedByMe: !wasBookmarked));

    try {
      if (wasBookmarked) {
        await _repository.unbookmarkVehicle(garageId: _garageId, vehicleId: _vehicleId);
      } else {
        await _repository.bookmarkVehicle(garageId: _garageId, vehicleId: _vehicleId);
      }
    } catch (e) {
      state = state.copyWith(vehicle: vehicle);
      rethrow;
    }
  }

  Future<void> addComment(String content) async {
    final comment = await _repository.createVehicleComment(
      garageId: _garageId,
      vehicleId: _vehicleId,
      content: content,
    );
    state = state.copyWith(
      comments: [...state.comments, comment],
      vehicle: state.vehicle?.copyWith(commentCount: (state.vehicle?.commentCount ?? 0) + 1),
    );
  }

  Future<void> deleteComment(String commentId) async {
    await _repository.deleteVehicleComment(garageId: _garageId, vehicleId: _vehicleId, commentId: commentId);
    state = state.copyWith(
      comments: [
        for (final c in state.comments)
          if (c.id == commentId)
            CartokVehicleComment(
              id: c.id,
              vehicleId: c.vehicleId,
              authorId: c.authorId,
              // Mirrors exactly what the server returns for a deleted
              // comment (see vehicles.service.ts#listComments) - masking
              // only the isDeleted flag locally while keeping the real
              // text would show the author their own comment's original
              // content after "deleting" it, until the next full reload.
              content: '[deleted]',
              isDeleted: true,
              createdAt: c.createdAt,
              editedAt: c.editedAt,
              author: c.author,
            )
          else
            c,
      ],
    );
  }
}

final vehicleDetailProvider = StateNotifierProvider.family<VehicleDetailNotifier, VehicleDetailState, (String, String)>(
  (ref, ids) {
    final (garageId, vehicleId) = ids;
    return VehicleDetailNotifier(ref.watch(garageRepositoryProvider), garageId, vehicleId);
  },
);
