class ConversationSummary {
  const ConversationSummary({
    required this.conversationId,
    required this.peerUserId,
    required this.peerDisplayName,
    this.peerAvatarUrl,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.isGroup = false,
    this.groupTitle,
    this.memberCount = 0,
    this.eventId,
  });

  final String conversationId;
  /// Pusty string dla czatów grupowych.
  final String peerUserId;
  final String peerDisplayName;
  final String? peerAvatarUrl;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final bool isGroup;
  final String? groupTitle;
  final int memberCount;
  final String? eventId;

  String get displayName => isGroup ? (groupTitle ?? 'Czat grupowy') : peerDisplayName;
}
