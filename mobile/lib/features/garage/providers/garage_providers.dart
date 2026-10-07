import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_dependencies_provider.dart';
import '../models/cartok_garage.dart';
import '../repository/garage_repository.dart';

final garageRepositoryProvider = Provider<GarageRepository>((ref) {
  return GarageRepository(ref.watch(apiClientProvider));
});

/// The signed-in user's garages. `.refresh()` (via ref.invalidate) is how
/// screens pull fresh data after creating a garage or adding a vehicle,
/// rather than hand-rolling manual refetch plumbing everywhere.
final myGaragesProvider = FutureProvider<List<CartokGarage>>((ref) {
  return ref.watch(garageRepositoryProvider).myGarages();
});

final garageDetailProvider = FutureProvider.family<CartokGarage, String>((ref, garageId) {
  return ref.watch(garageRepositoryProvider).getGarage(garageId);
});
