enum NotificationType { newMessage, eventJoin, forumLike, forumReply }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    required this.payload,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String? body;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;

  static NotificationType? _parseType(String? raw) {
    switch (raw) {
      case 'new_message':
        return NotificationType.newMessage;
      case 'event_join':
        return NotificationType.eventJoin;
      case 'forum_like':
        return NotificationType.forumLike;
      case 'forum_reply':
        return NotificationType.forumReply;
      default:
        return null;
    }
  }

  static AppNotification? tryFromRow(Map<String, dynamic> row) {
    final String id = row['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    final NotificationType? type = _parseType(row['type']?.toString());
    if (type == null) return null;
    return AppNotification(
      id: id,
      type: type,
      title: row['title']?.toString() ?? '',
      body: row['body']?.toString(),
      payload: (row['payload'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      isRead: row['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        payload: payload,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
