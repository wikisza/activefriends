class EventBadge {
  final String id;
  final String eventId;
  final String badgeCode;
  final String badgeLabel;
  final DateTime createdAt;

  const EventBadge({
    required this.id,
    required this.eventId,
    required this.badgeCode,
    required this.badgeLabel,
    required this.createdAt,
  });

  factory EventBadge.fromJson(Map<String, dynamic> json) => EventBadge(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        badgeCode: json['badge_code'] as String,
        badgeLabel: json['badge_label'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'badge_code': badgeCode,
        'badge_label': badgeLabel,
        'created_at': createdAt.toIso8601String(),
      };
}
