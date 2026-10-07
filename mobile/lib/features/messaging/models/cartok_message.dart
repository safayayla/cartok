class CartokMessageParticipant {
  const CartokMessageParticipant({required this.id, required this.username, required this.displayName, this.avatarUrl});

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  factory CartokMessageParticipant.fromJson(Map<String, dynamic> json) => CartokMessageParticipant(
        id: json['id'] as String,
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String?,
      );
}

class CartokMessage {
  const CartokMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.sender,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final CartokMessageParticipant? sender;

  factory CartokMessage.fromJson(Map<String, dynamic> json) => CartokMessage(
        id: json['id'] as String,
        conversationId: json['conversationId'] as String,
        senderId: json['senderId'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        sender: json['sender'] != null ? CartokMessageParticipant.fromJson(json['sender'] as Map<String, dynamic>) : null,
      );
}

/// A row from the conversation list endpoint — distinct shape from a raw
/// Conversation (see CartokConversationDetail below), matching
/// messaging.service.ts#listConversations exactly: it's pre-joined with
/// the other participant and last message rather than a full participants
/// array, since the list view never needs to render a group conversation
/// (DMs only, see the backend's own scope comment).
class CartokConversationSummary {
  const CartokConversationSummary({
    required this.conversationId,
    required this.otherParticipant,
    required this.lastMessage,
    required this.isUnread,
    required this.updatedAt,
  });

  final String conversationId;
  final CartokMessageParticipant? otherParticipant;
  final CartokMessage? lastMessage;
  final bool isUnread;
  final DateTime updatedAt;

  factory CartokConversationSummary.fromJson(Map<String, dynamic> json) => CartokConversationSummary(
        conversationId: json['conversationId'] as String,
        otherParticipant: json['otherParticipant'] != null
            ? CartokMessageParticipant.fromJson(json['otherParticipant'] as Map<String, dynamic>)
            : null,
        lastMessage:
            json['lastMessage'] != null ? CartokMessage.fromJson(json['lastMessage'] as Map<String, dynamic>) : null,
        isUnread: json['isUnread'] as bool? ?? false,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

/// The raw conversation object returned by getOrCreateDm — has a full
/// participants array rather than the pre-joined "other participant" shape
/// the list endpoint returns.
class CartokConversationDetail {
  const CartokConversationDetail({required this.id, required this.participants});

  final String id;
  final List<CartokMessageParticipant> participants;

  factory CartokConversationDetail.fromJson(Map<String, dynamic> json) => CartokConversationDetail(
        id: json['id'] as String,
        participants: (json['participants'] as List<dynamic>)
            .map((p) => CartokMessageParticipant.fromJson((p as Map<String, dynamic>)['user'] as Map<String, dynamic>))
            .toList(),
      );
}
