enum ParticipantRole { member, organizer, helper }

class EventParticipant {
  final String eventId;
  final String profileId;
  final ParticipantRole role;
  final DateTime joinedAt;

  const EventParticipant({
    required this.eventId,
    required this.profileId,
    required this.role,
    required this.joinedAt,
  });

  factory EventParticipant.fromJson(Map<String, dynamic> json) =>
      EventParticipant(
        eventId: json['event_id'] as String,
        profileId: json['profile_id'] as String,
        role: ParticipantRole.values.byName(json['role'] as String),
        joinedAt: DateTime.parse(json['joined_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'profile_id': profileId,
        'role': role.name,
        'joined_at': joinedAt.toIso8601String(),
      };
}
