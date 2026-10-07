class CartokUser {
  const CartokUser({
    required this.id,
    required this.email,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    required this.verification,
  });

  final String id;
  final String email;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String verification; // UNVERIFIED | PENDING | VERIFIED | REJECTED

  factory CartokUser.fromJson(Map<String, dynamic> json) => CartokUser(
        id: json['id'] as String,
        email: json['email'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        bio: json['bio'] as String?,
        verification: json['verification'] as String? ?? 'UNVERIFIED',
      );
}
