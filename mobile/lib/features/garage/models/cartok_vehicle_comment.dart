class CartokCommentAuthor {
  const CartokCommentAuthor({required this.id, required this.username, required this.displayName, this.avatarUrl});

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory CartokCommentAuthor.fromJson(Map<String, dynamic> json) => CartokCommentAuthor(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class CartokVehicleComment {
  const CartokVehicleComment({
    required this.id,
    required this.vehicleId,
    required this.authorId,
    required this.content,
    required this.isDeleted,
    required this.createdAt,
    this.editedAt,
    required this.author,
  });

  final String id;
  final String vehicleId;
  final String authorId;
  final String content;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? editedAt;
  final CartokCommentAuthor author;

  factory CartokVehicleComment.fromJson(Map<String, dynamic> json) => CartokVehicleComment(
        id: json['id'] as String,
        vehicleId: json['vehicleId'] as String,
        authorId: json['authorId'] as String,
        content: json['content'] as String,
        isDeleted: json['isDeleted'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt'] as String) : null,
        author: CartokCommentAuthor.fromJson(json['author'] as Map<String, dynamic>),
      );
}
