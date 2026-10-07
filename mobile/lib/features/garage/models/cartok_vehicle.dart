class CartokVehicle {
  const CartokVehicle({
    required this.id,
    required this.garageId,
    this.vin,
    required this.make,
    required this.model,
    required this.year,
    this.trim,
    this.nickname,
    this.odometer,
    required this.odometerUnit,
    required this.isPublic,
    required this.verificationStatus,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLikedByMe = false,
    this.isBookmarkedByMe = false,
  });

  final String id;
  final String garageId;
  final String? vin;
  final String make;
  final String model;
  final int year;
  final String? trim;
  final String? nickname;
  final int? odometer;
  final String odometerUnit;
  final bool isPublic;
  final String verificationStatus;
  // Only populated by the dedicated single-vehicle endpoint
  // (GET /garages/:garageId/vehicles/:vehicleId) - a vehicle embedded in a
  // garage's vehicle list (GET /garages/:garageId) won't have these set,
  // since that query never joins likes/comments. Default to 0/false so
  // parsing either response shape is always safe.
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;
  final bool isBookmarkedByMe;

  String get title => nickname?.isNotEmpty == true ? nickname! : '$year $make $model';
  String get subtitle => trim?.isNotEmpty == true ? '$make $model · $trim' : '$make $model';

  CartokVehicle copyWith({int? likeCount, bool? isLikedByMe, int? commentCount, bool? isBookmarkedByMe}) => CartokVehicle(
        id: id,
        garageId: garageId,
        vin: vin,
        make: make,
        model: model,
        year: year,
        trim: trim,
        nickname: nickname,
        odometer: odometer,
        odometerUnit: odometerUnit,
        isPublic: isPublic,
        verificationStatus: verificationStatus,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        isLikedByMe: isLikedByMe ?? this.isLikedByMe,
        isBookmarkedByMe: isBookmarkedByMe ?? this.isBookmarkedByMe,
      );

  factory CartokVehicle.fromJson(Map<String, dynamic> json) => CartokVehicle(
        id: json['id'] as String,
        garageId: json['garageId'] as String,
        vin: json['vin'] as String?,
        make: json['make'] as String,
        model: json['model'] as String,
        year: json['year'] as int,
        trim: json['trim'] as String?,
        nickname: json['nickname'] as String?,
        odometer: json['odometer'] as int?,
        odometerUnit: json['odometerUnit'] as String? ?? 'mi',
        isPublic: json['isPublic'] as bool? ?? true,
        verificationStatus: json['verificationStatus'] as String? ?? 'UNVERIFIED',
        likeCount: (json['_count'] as Map<String, dynamic>?)?['likes'] as int? ?? 0,
        commentCount: (json['_count'] as Map<String, dynamic>?)?['comments'] as int? ?? 0,
        isLikedByMe: json['isLikedByMe'] as bool? ?? false,
        isBookmarkedByMe: json['isBookmarkedByMe'] as bool? ?? false,
      );
}
