import 'package:activefriends/src/features/map/data/event_repository.dart';
import 'package:activefriends/src/features/map/domain/event_models.dart';
import 'package:activefriends/src/models/event.dart' as event_model;
import 'package:latlong2/latlong.dart';

class MockEventRepository implements EventRepository {
  MockEventRepository();

  final List<EventPin> _items = <EventPin>[
    EventPin(
      id: 'bike-1',
      title: 'Wycieczka Rowerowa Bydgoszcz -> Gdansk',
      subtitle: 'Start: Stary Rynek, sobota 7:30',
      location: const LatLng(53.1226, 18.0083),
      topic: 'Rower',
      organizer: const UserProfile(
        id: 'anna',
        displayName: 'Anna',
        verificationLevel: VerificationLevel.level2,
      ),
      scenario: EventScenario.bikeRide,
      badges: const <String>['OTWARTA GRUPA'],
      photoLabel: 'Profil Anny',
    ),
    EventPin(
      id: 'moto-1',
      title: 'Pilne: Awaria motocykla',
      subtitle: 'Bydgoszcz, ul. Torunska 44, potrzebna pomoc',
      location: const LatLng(53.1178, 18.0377),
      topic: 'Pomoc',
      organizer: const UserProfile(
        id: 'marek',
        displayName: 'Marek',
        verificationLevel: VerificationLevel.level1,
      ),
      scenario: EventScenario.emergency,
      badges: const <String>['PILNE'],
      photoLabel: 'Zdjecie awarii',
    ),
    EventPin(
      id: 'social-1',
      title: 'Ceramika dla Seniora',
      subtitle: 'Dom Kultury, wtorek 11:00',
      location: const LatLng(53.1292, 18.0146),
      topic: 'Ceramika',
      organizer: const UserProfile(
        id: 'alina',
        displayName: 'Alina',
        verificationLevel: VerificationLevel.level3,
      ),
      scenario: EventScenario.social,
      badges: const <String>[
        'PRZYJAZNE SENIOROM',
        'Tylko zweryfikowani Poziom 3',
      ],
      photoLabel: 'Seniorka',
    ),
  ];

  @override
  Future<List<EventPin>> fetchPins({
    String? query,
    List<String>? topics,
  }) async {
    final String normalizedQuery = (query ?? '').trim().toLowerCase();
    final Set<String> topicSet = topics?.toSet() ?? <String>{};

    return _items.where((EventPin item) {
      final bool queryMatch = normalizedQuery.isEmpty ||
          item.title.toLowerCase().contains(normalizedQuery) ||
          item.subtitle.toLowerCase().contains(normalizedQuery);
      final bool topicMatch = topicSet.isEmpty || topicSet.contains(item.topic);
      return queryMatch && topicMatch;
    }).toList(growable: false);
  }

  @override
  Future<void> askQuestion(String eventId, String question) async {}

  @override
  Future<void> joinEvent(String eventId) async {}

  @override
  Future<void> reportLocal(String eventId) async {}

  @override
  Future<void> createEvent(event_model.Event event,
      {List<String> badges = const <String>[]}) async {
    // Mock: nie zapisuje do bazy danych
  }
}
