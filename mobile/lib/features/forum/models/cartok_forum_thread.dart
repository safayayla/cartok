class CartokForumThread {
  const CartokForumThread({
    required this.id,
    required this.categoryId,
    required this.authorId,
    required this.title,
    required this.slug,
    required this.isPinned,
    required this.isLocked,
    required this.viewCount,
    required this.postCount,
    required this.createdAt,
    required this.updatedAt,
    this.isBookmarkedByMe = false,
  });

  final String id;
  final String categoryId;
  final String authorId;
  final String title;
  final String slug;
  final bool isPinned;
  final bool isLocked;
  final int viewCount;
  final int postCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Only populated by the thread detail endpoint (GET /forum/threads/:id) -
  // the category thread list never joins bookmarks. Defaults to false so
  // parsing either response shape is always safe, same pattern as
  // CartokVehicle's isLikedByMe/likeCount.
  final bool isBookmarkedByMe;

  CartokForumThread copyWith({bool? isBookmarkedByMe}) => CartokForumThread(
        id: id,
        categoryId: categoryId,
        authorId: authorId,
        title: title,
        slug: slug,
        isPinned: isPinned,
        isLocked: isLocked,
        viewCount: viewCount,
        postCount: postCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isBookmarkedByMe: isBookmarkedByMe ?? this.isBookmarkedByMe,
      );

  factory CartokForumThread.fromJson(Map<String, dynamic> json) => CartokForumThread(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String,
        authorId: json['authorId'] as String,
        title: json['title'] as String,
        slug: json['slug'] as String,
        isPinned: json['isPinned'] as bool? ?? false,
        isLocked: json['isLocked'] as bool? ?? false,
        viewCount: json['viewCount'] as int? ?? 0,
        postCount: (json['_count'] as Map<String, dynamic>?)?['posts'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        isBookmarkedByMe: json['isBookmarkedByMe'] as bool? ?? false,
      );
}
