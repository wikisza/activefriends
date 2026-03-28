class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  static ChatMessage? tryFromRow(Map<String, dynamic> row) {
    final String id = row['id']?.toString() ?? '';
    if (id.isEmpty) {
      return null;
    }
    final DateTime? at =
        DateTime.tryParse(row['created_at']?.toString() ?? '');
    return ChatMessage(
      id: id,
      conversationId: row['conversation_id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      body: row['body']?.toString() ?? '',
      createdAt: at ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
