class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.peerUserId,
    required this.peerDisplayName,
    this.peerAvatarUrl,
    this.lastMessagePreview,
    this.lastMessageAt,
  });

  final String conversationId;
  final String peerUserId;
  final String peerDisplayName;
  final String? peerAvatarUrl;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
}
