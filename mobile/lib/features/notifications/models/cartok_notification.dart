class CartokNotification {
  const CartokNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.entityType,
    this.entityId,
  });

  final String id;
  final String type;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final String? entityType;
  final String? entityId;

  CartokNotification copyWith({bool? isRead}) => CartokNotification(
        id: id,
        type: type,
        message: message,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        entityType: entityType,
        entityId: entityId,
      );

  factory CartokNotification.fromJson(Map<String, dynamic> json) => CartokNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        message: json['message'] as String,
        isRead: json['isRead'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        entityType: json['entityType'] as String?,
        entityId: json['entityId'] as String?,
      );
}
