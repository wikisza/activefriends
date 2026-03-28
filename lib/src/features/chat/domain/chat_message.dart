class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.senderName,
    this.senderAvatarUrl,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatarUrl;

  static ChatMessage? tryFromRow(Map<String, dynamic> row) {
    final String id = row['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final DateTime? at =
        DateTime.tryParse(row['created_at']?.toString() ?? '');

    // profiles może być zagnieżdżone (join) lub w cache
    String? senderName;
    String? senderAvatarUrl;
    final dynamic profiles = row['profiles'];
    if (profiles is Map<String, dynamic>) {
      senderName = profiles['display_name']?.toString();
      senderAvatarUrl = profiles['avatar_url']?.toString();
    }

    return ChatMessage(
      id: id,
      conversationId: row['conversation_id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      body: row['body']?.toString() ?? '',
      createdAt: at ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
    );
  }

  ChatMessage withSender({String? name, String? avatarUrl}) => ChatMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        body: body,
        createdAt: createdAt,
        senderName: name ?? senderName,
        senderAvatarUrl: avatarUrl ?? senderAvatarUrl,
      );
}
