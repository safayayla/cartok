class CartokListingImage {
  const CartokListingImage({required this.id, required this.url, required this.sortOrder});

  final String id;
  final String url;
  final int sortOrder;

  factory CartokListingImage.fromJson(Map<String, dynamic> json) => CartokListingImage(
        id: json['id'] as String,
        url: json['url'] as String,
        sortOrder: json['sortOrder'] as int? ?? 0,
      );
}

class CartokListing {
  const CartokListing({
    required this.id,
    required this.sellerId,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    required this.priceCents,
    required this.currency,
    this.condition,
    this.vehicleId,
    this.location,
    required this.viewCount,
    required this.images,
    required this.createdAt,
  });

  final String id;
  final String sellerId;
  final String type;
  final String status;
  final String title;
  final String description;
  final int priceCents;
  final String currency;
  final String? condition;
  final String? vehicleId;
  final String? location;
  final int viewCount;
  final List<CartokListingImage> images;
  final DateTime createdAt;

  String get formattedPrice {
    final dollars = priceCents / 100;
    return '\$${dollars.toStringAsFixed(dollars.truncateToDouble() == dollars ? 0 : 2)}';
  }

  factory CartokListing.fromJson(Map<String, dynamic> json) => CartokListing(
        id: json['id'] as String,
        sellerId: json['sellerId'] as String,
        type: json['type'] as String,
        status: json['status'] as String? ?? 'ACTIVE',
        title: json['title'] as String,
        description: json['description'] as String,
        priceCents: json['priceCents'] as int,
        currency: json['currency'] as String? ?? 'USD',
        condition: json['condition'] as String?,
        vehicleId: json['vehicleId'] as String?,
        location: json['location'] as String?,
        viewCount: json['viewCount'] as int? ?? 0,
        images: (json['images'] as List<dynamic>? ?? [])
            .map((i) => CartokListingImage.fromJson(i as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
