class CartokPublicProfile {
  const CartokPublicProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    required this.verification,
    required this.createdAt,
    required this.followerCount,
    required this.followingCount,
    required this.isFollowedByMe,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String verification;
  final DateTime createdAt;
  final int followerCount;
  final int followingCount;
  final bool isFollowedByMe;

  CartokPublicProfile copyWith({int? followerCount, bool? isFollowedByMe}) => CartokPublicProfile(
        id: id,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        bio: bio,
        verification: verification,
        createdAt: createdAt,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount,
        isFollowedByMe: isFollowedByMe ?? this.isFollowedByMe,
      );

  factory CartokPublicProfile.fromJson(Map<String, dynamic> json) => CartokPublicProfile(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        bio: json['bio'] as String?,
        verification: json['verification'] as String? ?? 'UNVERIFIED',
        createdAt: DateTime.parse(json['createdAt'] as String),
        followerCount: json['followerCount'] as int? ?? 0,
        followingCount: json['followingCount'] as int? ?? 0,
        isFollowedByMe: json['isFollowedByMe'] as bool? ?? false,
      );
}

class CartokFollowUser {
  const CartokFollowUser({required this.id, required this.username, required this.displayName, this.avatarUrl});

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory CartokFollowUser.fromJson(Map<String, dynamic> json) => CartokFollowUser(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
      );
}
