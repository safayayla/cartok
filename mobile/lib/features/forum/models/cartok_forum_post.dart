class CartokPostAuthor {
  const CartokPostAuthor({required this.id, required this.username, required this.displayName, this.avatarUrl});

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory CartokPostAuthor.fromJson(Map<String, dynamic> json) => CartokPostAuthor(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class CartokForumPost {
  const CartokForumPost({
    required this.id,
    required this.threadId,
    required this.authorId,
    this.parentId,
    required this.content,
    required this.isDeleted,
    required this.score,
    required this.createdAt,
    this.editedAt,
    required this.author,
    this.myVote,
  });

  final String id;
  final String threadId;
  final String authorId;
  final String? parentId;
  final String content;
  final bool isDeleted;
  final int score;
  final DateTime createdAt;
  final DateTime? editedAt;
  final CartokPostAuthor author;
  // Not returned by the API today (no per-user vote state in the response
  // yet) - kept client-side only, so the UI can reflect the button state
  // immediately after voting without waiting on a full re-fetch. Resets to
  // null on next full reload, which is an acceptable trade-off until the
  // backend includes it directly.
  final int? myVote;

  CartokForumPost copyWith({int? score, int? myVote, bool clearMyVote = false}) => CartokForumPost(
        id: id,
        threadId: threadId,
        authorId: authorId,
        parentId: parentId,
        content: content,
        isDeleted: isDeleted,
        score: score ?? this.score,
        createdAt: createdAt,
        editedAt: editedAt,
        author: author,
        myVote: clearMyVote ? null : (myVote ?? this.myVote),
      );

  factory CartokForumPost.fromJson(Map<String, dynamic> json) => CartokForumPost(
        id: json['id'] as String,
        threadId: json['threadId'] as String,
        authorId: json['authorId'] as String,
        parentId: json['parentId'] as String?,
        content: json['content'] as String,
        isDeleted: json['isDeleted'] as bool? ?? false,
        score: json['score'] as int? ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
        editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt'] as String) : null,
        author: CartokPostAuthor.fromJson(json['author'] as Map<String, dynamic>),
      );
}

class CartokForumThreadDetail {
  const CartokForumThreadDetail({required this.thread, required this.posts});

  final CartokForumThread thread;
  final List<CartokForumPost> posts;

  factory CartokForumThreadDetail.fromJson(Map<String, dynamic> json) => CartokForumThreadDetail(
        thread: CartokForumThread.fromJson(json),
        posts: (json['posts'] as List<dynamic>? ?? [])
            .map((p) => CartokForumPost.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
