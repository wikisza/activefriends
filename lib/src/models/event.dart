enum EventScenario { bikeRide, emergency, social }

enum EventStatus { open, closed, cancelled }

class Event {
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final EventScenario scenario;
  final EventStatus status;
  final String organizerId;
  final double lat;
  final double lng;
  final String city;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? photoUrl;
  final DateTime createdAt;

  const Event({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    required this.scenario,
    required this.status,
    required this.organizerId,
    required this.lat,
    required this.lng,
    required this.city,
    this.startsAt,
    this.endsAt,
    this.photoUrl,
    required this.createdAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String?,
        description: json['description'] as String?,
        scenario: EventScenario.values.byName(json['scenario'] as String),
        status: EventStatus.values.byName(json['status'] as String),
        organizerId: json['organizer_id'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        city: json['city'] as String,
        startsAt: json['starts_at'] != null
            ? DateTime.parse(json['starts_at'] as String)
            : null,
        endsAt: json['ends_at'] != null
            ? DateTime.parse(json['ends_at'] as String)
            : null,
        photoUrl: json['photo_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'description': description,
        'scenario': scenario.name,
        'status': status.name,
        'organizer_id': organizerId,
        'lat': lat,
        'lng': lng,
        'city': city,
        'starts_at': startsAt?.toIso8601String(),
        'ends_at': endsAt?.toIso8601String(),
        'photo_url': photoUrl,
        'created_at': createdAt.toIso8601String(),
      };
}
