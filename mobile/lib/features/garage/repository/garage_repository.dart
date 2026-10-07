import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../auth/repository/auth_repository.dart';
import '../models/cartok_garage.dart';
import '../models/cartok_vehicle.dart';
import '../models/cartok_vehicle_comment.dart';

class VinDecodeResult {
  const VinDecodeResult({this.make, this.model, this.modelYear, this.trim, this.bodyClass});
  final String? make;
  final String? model;
  final String? modelYear;
  final String? trim;
  final String? bodyClass;

  factory VinDecodeResult.fromJson(Map<String, dynamic> json) => VinDecodeResult(
        make: json['make'] as String?,
        model: json['model'] as String?,
        modelYear: json['modelYear'] as String?,
        trim: json['trim'] as String?,
        bodyClass: json['bodyClass'] as String?,
      );
}

class GarageRepository {
  GarageRepository(this._client);

  final ApiClient _client;

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    final message = (data is Map && data['error'] != null)
        ? (data['error']['message'] as String? ?? 'Something went wrong')
        : 'Network error — please check your connection';
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  Future<List<CartokGarage>> myGarages() async {
    try {
      final res = await _client.dio.get('/api/v1/garages/mine');
      return (res.data['data'] as List<dynamic>)
          .map((g) => CartokGarage.fromJson(g as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokGarage> createGarage({required String name, String? description}) async {
    try {
      final res = await _client.dio.post('/api/v1/garages', data: {
        'name': name,
        if (description != null && description.isNotEmpty) 'description': description,
      });
      return CartokGarage.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokGarage> getGarage(String garageId) async {
    try {
      final res = await _client.dio.get('/api/v1/garages/$garageId');
      return CartokGarage.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> followGarage(String garageId) async {
    try {
      await _client.dio.post('/api/v1/garages/$garageId/follow');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> unfollowGarage(String garageId) async {
    try {
      await _client.dio.delete('/api/v1/garages/$garageId/follow');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<VinDecodeResult?> decodeVin(String vin) async {
    try {
      final res = await _client.dio.get('/api/v1/vin/$vin');
      return VinDecodeResult.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException {
      // Enrichment only — a failed decode should never block adding the vehicle.
      return null;
    }
  }

  Future<CartokVehicle> addVehicle({
    required String garageId,
    String? vin,
    required String make,
    required String model,
    required int year,
    String? trim,
    String? nickname,
    int? odometer,
    String odometerUnit = 'mi',
  }) async {
    try {
      final res = await _client.dio.post('/api/v1/garages/$garageId/vehicles', data: {
        if (vin != null && vin.isNotEmpty) 'vin': vin,
        'make': make,
        'model': model,
        'year': year,
        if (trim != null && trim.isNotEmpty) 'trim': trim,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
        if (odometer != null) 'odometer': odometer,
        'odometerUnit': odometerUnit,
      });
      return CartokVehicle.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteVehicle({required String garageId, required String vehicleId}) async {
    try {
      await _client.dio.delete('/api/v1/garages/$garageId/vehicles/$vehicleId');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// The dedicated single-vehicle endpoint, distinct from the vehicle list
  /// embedded in getGarage() — this one includes like/comment counts and
  /// the viewer's own like state, which the embedded list never does.
  Future<CartokVehicle> getVehicle({required String garageId, required String vehicleId}) async {
    try {
      final res = await _client.dio.get('/api/v1/garages/$garageId/vehicles/$vehicleId');
      return CartokVehicle.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> likeVehicle({required String garageId, required String vehicleId}) async {
    try {
      await _client.dio.post('/api/v1/garages/$garageId/vehicles/$vehicleId/like');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> unlikeVehicle({required String garageId, required String vehicleId}) async {
    try {
      await _client.dio.delete('/api/v1/garages/$garageId/vehicles/$vehicleId/like');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> bookmarkVehicle({required String garageId, required String vehicleId}) async {
    try {
      await _client.dio.post('/api/v1/garages/$garageId/vehicles/$vehicleId/bookmark');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> unbookmarkVehicle({required String garageId, required String vehicleId}) async {
    try {
      await _client.dio.delete('/api/v1/garages/$garageId/vehicles/$vehicleId/bookmark');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<CartokVehicle>> listBookmarkedVehicles() async {
    try {
      final res = await _client.dio.get('/api/v1/garages/vehicle-bookmarks');
      return (res.data['data'] as List<dynamic>)
          .map((v) => CartokVehicle.fromJson(v as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<CartokVehicleComment>> listVehicleComments({required String garageId, required String vehicleId}) async {
    try {
      final res = await _client.dio.get('/api/v1/garages/$garageId/vehicles/$vehicleId/comments');
      return (res.data['data'] as List<dynamic>)
          .map((c) => CartokVehicleComment.fromJson(c as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<CartokVehicleComment> createVehicleComment({
    required String garageId,
    required String vehicleId,
    required String content,
  }) async {
    try {
      final res = await _client.dio.post(
        '/api/v1/garages/$garageId/vehicles/$vehicleId/comments',
        data: {'content': content},
      );
      return CartokVehicleComment.fromJson(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<void> deleteVehicleComment({
    required String garageId,
    required String vehicleId,
    required String commentId,
  }) async {
    try {
      await _client.dio.delete('/api/v1/garages/$garageId/vehicles/$vehicleId/comments/$commentId');
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }
}
