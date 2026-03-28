class EventRoute {
  final String id;
  final String eventId;
  final String provider;
  final Map<String, dynamic> geometryGeojson;
  final int? distanceM;
  final int? durationS;
  final DateTime createdAt;

  const EventRoute({
    required this.id,
    required this.eventId,
    required this.provider,
    required this.geometryGeojson,
    this.distanceM,
    this.durationS,
    required this.createdAt,
  });

  factory EventRoute.fromJson(Map<String, dynamic> json) => EventRoute(
        id: json['id'] as String,
        eventId: json['event_id'] as String,
        provider: json['provider'] as String,
        geometryGeojson: json['geometry_geojson'] as Map<String, dynamic>,
        distanceM: json['distance_m'] as int?,
        durationS: json['duration_s'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'provider': provider,
        'geometry_geojson': geometryGeojson,
        'distance_m': distanceM,
        'duration_s': durationS,
        'created_at': createdAt.toIso8601String(),
      };
}
