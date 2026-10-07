class CartokEventHost {
  const CartokEventHost({required this.id, required this.username, required this.displayName, this.avatarUrl});

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory CartokEventHost.fromJson(Map<String, dynamic> json) => CartokEventHost(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class CartokEvent {
  const CartokEvent({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.locationName,
    this.latitude,
    this.longitude,
    required this.startTime,
    this.endTime,
    this.capacity,
    required this.hostId,
    this.host,
    required this.isCancelled,
    required this.checkInCode,
    required this.goingCount,
    this.checkInCount,
  });

  final String id;
  final String type; // CARS_AND_COFFEE | DRIVE_TOGETHER | MEETUP | TRACK_DAY | OTHER
  final String title;
  final String? description;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final DateTime startTime;
  final DateTime? endTime;
  final int? capacity;
  final String hostId;
  final CartokEventHost? host;
  final bool isCancelled;
  final String checkInCode;
  final int goingCount;
  final int? checkInCount;

  bool get isFull => capacity != null && goingCount >= capacity!;

  CartokEvent copyWith({int? goingCount}) => CartokEvent(
        id: id,
        type: type,
        title: title,
        description: description,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        startTime: startTime,
        endTime: endTime,
        capacity: capacity,
        hostId: hostId,
        host: host,
        isCancelled: isCancelled,
        checkInCode: checkInCode,
        goingCount: goingCount ?? this.goingCount,
        checkInCount: checkInCount,
      );

  String get typeLabel {
    switch (type) {
      case 'CARS_AND_COFFEE':
        return 'Cars & Coffee';
      case 'DRIVE_TOGETHER':
        return 'Drive Together';
      case 'TRACK_DAY':
        return 'Track Day';
      case 'MEETUP':
        return 'Meetup';
      default:
        return 'Event';
    }
  }

  factory CartokEvent.fromJson(Map<String, dynamic> json) => CartokEvent(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        locationName: json['locationName'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
        capacity: json['capacity'] as int?,
        hostId: json['hostId'] as String,
        host: json['host'] != null ? CartokEventHost.fromJson(json['host'] as Map<String, dynamic>) : null,
        isCancelled: json['isCancelled'] as bool? ?? false,
        checkInCode: json['checkInCode'] as String? ?? '',
        goingCount: (json['_count'] as Map<String, dynamic>?)?['rsvps'] as int? ?? 0,
        checkInCount: (json['_count'] as Map<String, dynamic>?)?['checkIns'] as int?,
      );
}
