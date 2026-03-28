class LocalReport {
  final String id;
  final String eventId;
  final String? reporterId;
  final String? reason;
  final DateTime createdAt;

  const LocalReport({
    required this.id,
    required this.eventId,
    this.reporterId,
    this.reason,
    required this.createdAt,
  });

  factory LocalReport.fromJson(Map<String, dynamic> json) => LocalReport(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        reporterId: json['reporter_id'] as String?,
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'reporter_id': reporterId,
        'reason': reason,
        'created_at': createdAt.toIso8601String(),
      };
}
