import 'package:latlong2/latlong.dart';

enum EventScenario { bikeRide, emergency, social }

enum VerificationLevel {
  level1('Weryfikacja Poziom 1'),
  level2('Weryfikacja Poziom 2'),
  level3('Weryfikacja Poziom 3');

  const VerificationLevel(this.label);
  final String label;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.verificationLevel,
  });

  final String id;
  final String displayName;
  final VerificationLevel verificationLevel;
}

class EventPin {
  const EventPin({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.topic,
    required this.organizer,
    required this.scenario,
    required this.badges,
    this.photoLabel,
    this.participationRole,
  });

  final String id;
  final String title;
  final String subtitle;
  final LatLng location;
  final String topic;
  final UserProfile organizer;
  final EventScenario scenario;
  final List<String> badges;
  final String? photoLabel;
  final String? participationRole;
}
