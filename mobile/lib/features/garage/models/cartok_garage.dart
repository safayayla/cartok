import 'cartok_vehicle.dart';

class CartokGarage {
  const CartokGarage({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slug,
    this.description,
    this.coverUrl,
    required this.isPublic,
    this.vehicles = const [],
    this.followerCount = 0,
    this.isFollowedByMe = false,
  });

  final String id;
  final String ownerId;
  final String name;
  final String slug;
  final String? description;
  final String? coverUrl;
  final bool isPublic;
  final List<CartokVehicle> vehicles;
  final int followerCount;
  final bool isFollowedByMe;

  CartokGarage copyWith({int? followerCount, bool? isFollowedByMe}) => CartokGarage(
        id: id,
        ownerId: ownerId,
        name: name,
        slug: slug,
        description: description,
        coverUrl: coverUrl,
        isPublic: isPublic,
        vehicles: vehicles,
        followerCount: followerCount ?? this.followerCount,
        isFollowedByMe: isFollowedByMe ?? this.isFollowedByMe,
      );

  factory CartokGarage.fromJson(Map<String, dynamic> json) => CartokGarage(
        id: json['id'] as String,
        ownerId: json['ownerId'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
        coverUrl: json['coverUrl'] as String?,
        isPublic: json['isPublic'] as bool? ?? true,
        vehicles: (json['vehicles'] as List<dynamic>? ?? [])
            .map((v) => CartokVehicle.fromJson(v as Map<String, dynamic>))
            .toList(),
        followerCount: (json['_count'] as Map<String, dynamic>?)?['followers'] as int? ?? 0,
        isFollowedByMe: json['isFollowedByMe'] as bool? ?? false,
      );
}
