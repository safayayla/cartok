class CartokFeedVehicle {
  const CartokFeedVehicle({
    required this.id,
    required this.garageId,
    required this.make,
    required this.model,
    required this.year,
    this.nickname,
    required this.likeCount,
    required this.commentCount,
    required this.garageName,
  });

  final String id;
  final String garageId;
  final String make;
  final String model;
  final int year;
  final String? nickname;
  final int likeCount;
  final int commentCount;
  final String garageName;

  String get title => nickname?.isNotEmpty == true ? nickname! : '$year $make $model';

  factory CartokFeedVehicle.fromJson(Map<String, dynamic> json) => CartokFeedVehicle(
        id: json['id'] as String,
        garageId: json['garageId'] as String,
        make: json['make'] as String,
        model: json['model'] as String,
        year: json['year'] as int,
        nickname: json['nickname'] as String?,
        likeCount: json['likeCount'] as int? ?? 0,
        commentCount: json['commentCount'] as int? ?? 0,
        garageName: (json['garage'] as Map<String, dynamic>?)?['name'] as String? ?? 'Garage',
      );
}

class CartokFeedThread {
  const CartokFeedThread({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.postCount,
    required this.authorDisplayName,
  });

  final String id;
  final String categoryId;
  final String title;
  final int postCount;
  final String authorDisplayName;

  factory CartokFeedThread.fromJson(Map<String, dynamic> json) => CartokFeedThread(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        title: json['title'] as String,
        postCount: json['postCount'] as int? ?? 0,
        authorDisplayName: (json['author'] as Map<String, dynamic>?)?['displayName'] as String? ?? 'Someone',
      );
}

class CartokFeedEvent {
  const CartokFeedEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.locationName,
    required this.startTime,
    required this.rsvpCount,
  });

  final String id;
  final String type;
  final String title;
  final String locationName;
  final DateTime startTime;
  final int rsvpCount;

  factory CartokFeedEvent.fromJson(Map<String, dynamic> json) => CartokFeedEvent(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        locationName: json['locationName'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        rsvpCount: json['rsvpCount'] as int? ?? 0,
      );
}

enum CartokFeedItemType { vehicle, thread, event }

/// A single blended feed entry. Exactly one of [vehicle]/[thread]/[event]
/// is non-null, matching [itemType] — this wrapper exists so the feed
/// screen can render a single heterogeneous list without a big switch on
/// raw JSON at the widget layer.
class CartokFeedItem {
  const CartokFeedItem({required this.itemType, this.vehicle, this.thread, this.event});

  final CartokFeedItemType itemType;
  final CartokFeedVehicle? vehicle;
  final CartokFeedThread? thread;
  final CartokFeedEvent? event;

  factory CartokFeedItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final item = json['item'] as Map<String, dynamic>;
    switch (type) {
      case 'vehicle':
        return CartokFeedItem(itemType: CartokFeedItemType.vehicle, vehicle: CartokFeedVehicle.fromJson(item));
      case 'thread':
        return CartokFeedItem(itemType: CartokFeedItemType.thread, thread: CartokFeedThread.fromJson(item));
      case 'event':
        return CartokFeedItem(itemType: CartokFeedItemType.event, event: CartokFeedEvent.fromJson(item));
      default:
        // Forward-compatible: an unrecognized type from a newer backend
        // shouldn't crash the whole feed parse, just gets filtered out by
        // the repository (see discover_repository.dart).
        throw FormatException('Unknown feed item type: $type');
    }
  }
}
