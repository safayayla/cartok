class CartokForumCategory {
  const CartokForumCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final int sortOrder;

  factory CartokForumCategory.fromJson(Map<String, dynamic> json) => CartokForumCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        description: json['description'] as String?,
        sortOrder: json['sortOrder'] as int? ?? 0,
      );
}
