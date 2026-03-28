import 'package:activefriends/src/features/map/data/event_api_client.dart';
import 'package:activefriends/src/features/map/domain/event_models.dart';
import 'package:activefriends/src/models/event.dart' as model;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class EventRepository {
  Future<List<EventPin>> fetchPins({
    String? query,
    List<String>? topics,
  });

  Future<void> joinEvent(String eventId);

  Future<void> askQuestion(String eventId, String question);

  Future<void> reportLocal(String eventId);

  /// Wstawia nowe wydarzenie do tabeli `events`.
  /// Wymaga zalogowanego użytkownika (auth.uid() = organizer_id).
  /// [badges] – opcjonalna lista odznak (PILNE, TYLKO ZWERYFIKOWANI itp.)
  /// zapisywanych do tabeli `event_badges`.
  Future<void> createEvent(model.Event event,
      {List<String> badges = const <String>[]});
}

// ---------------------------------------------------------------------------
// HTTP-based implementation (legacy)
// ---------------------------------------------------------------------------

class ApiEventRepository implements EventRepository {
  ApiEventRepository({required this.apiClient});

  final EventApiClient apiClient;

  @override
  Future<List<EventPin>> fetchPins({
    String? query,
    List<String>? topics,
  }) {
    return apiClient.fetchPins(query: query, topics: topics);
  }

  @override
  Future<void> joinEvent(String eventId) {
    return apiClient.joinEvent(eventId);
  }

  @override
  Future<void> askQuestion(String eventId, String question) {
    return apiClient.askQuestion(eventId, question);
  }

  @override
  Future<void> reportLocal(String eventId) {
    return apiClient.reportLocal(eventId);
  }

  @override
  Future<void> createEvent(model.Event event,
      {List<String> badges = const <String>[]}) {
    throw UnimplementedError(
      'Użyj SupabaseEventRepository.createEvent() zamiast ApiEventRepository.',
    );
  }
}

// ---------------------------------------------------------------------------
// Supabase implementation
// ---------------------------------------------------------------------------

/// Repozytorium oparte o [supabase_flutter].
/// Metoda [createEvent] konwertuje współrzędne do formatu PostGIS Point
/// i zapisuje wiersz w tabeli `events`.
class SupabaseEventRepository implements EventRepository {
  SupabaseEventRepository() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<EventPin>> fetchPins({
    String? query,
    List<String>? topics,
  }) async {
    try {
      final List<dynamic> rawEvents = await _client
          .from('events')
          .select('id,title,subtitle,scenario,organizer_id,lat,lng')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> events = rawEvents
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);

      if (events.isEmpty) {
        return <EventPin>[];
      }

      final Set<String> organizerIds = events
          .map((Map<String, dynamic> e) => e['organizer_id']?.toString() ?? '')
          .where((String id) => id.isNotEmpty)
          .toSet();

      final Map<String, UserProfile> organizersById = <String, UserProfile>{};
      if (organizerIds.isNotEmpty) {
        final List<dynamic> rawProfiles = await _client
            .from('profiles')
            .select('id,display_name,verification_level')
            .inFilter('id', organizerIds.toList(growable: false));

        for (final Map<String, dynamic> row
            in rawProfiles.whereType<Map<String, dynamic>>()) {
          final String id = row['id']?.toString() ?? '';
          if (id.isEmpty) {
            continue;
          }
          final int levelRaw = (row['verification_level'] as num?)?.toInt() ?? 1;
          final VerificationLevel level = switch (levelRaw) {
            3 => VerificationLevel.level3,
            2 => VerificationLevel.level2,
            _ => VerificationLevel.level1,
          };

          organizersById[id] = UserProfile(
            id: id,
            displayName: row['display_name']?.toString() ?? 'Uzytkownik',
            verificationLevel: level,
          );
        }
      }

      final Set<String> eventIds = events
          .map((Map<String, dynamic> e) => e['id']?.toString() ?? '')
          .where((String id) => id.isNotEmpty)
          .toSet();

      final Map<String, List<String>> badgesByEventId = <String, List<String>>{};
      if (eventIds.isNotEmpty) {
        final List<dynamic> rawBadges = await _client
            .from('event_badges')
            .select('event_id,badge_label')
            .inFilter('event_id', eventIds.toList(growable: false));

        for (final Map<String, dynamic> row
            in rawBadges.whereType<Map<String, dynamic>>()) {
          final String eventId = row['event_id']?.toString() ?? '';
          if (eventId.isEmpty) {
            continue;
          }
          final String label = row['badge_label']?.toString() ?? '';
          if (label.isEmpty) {
            continue;
          }
          badgesByEventId.putIfAbsent(eventId, () => <String>[]).add(label);
        }
      }

      final String normalizedQuery = (query ?? '').trim().toLowerCase();
      final Set<String> topicSet = (topics ?? <String>[]).toSet();

      final List<EventPin> pins = events.map((Map<String, dynamic> row) {
        final String scenarioRaw = row['scenario']?.toString() ?? '';
        final EventScenario scenario = switch (scenarioRaw) {
          'emergency' => EventScenario.emergency,
          'social' => EventScenario.social,
          _ => EventScenario.bikeRide,
        };

        final String topic = switch (scenario) {
          EventScenario.bikeRide => 'Rower',
          EventScenario.emergency => 'Pomoc',
          EventScenario.social => 'Ceramika',
        };

        final String eventId = row['id']?.toString() ?? 'unknown';
        final String organizerId = row['organizer_id']?.toString() ?? 'unknown';
        final UserProfile organizer = organizersById[organizerId] ??
            const UserProfile(
              id: 'unknown',
              displayName: 'Organizator',
              verificationLevel: VerificationLevel.level1,
            );

        final double lat = (row['lat'] as num?)?.toDouble() ?? 53.1235;
        final double lng = (row['lng'] as num?)?.toDouble() ?? 18.0084;

        return EventPin(
          id: eventId,
          title: row['title']?.toString() ?? 'Bez nazwy',
          subtitle: row['subtitle']?.toString() ?? 'Brak opisu',
          location: LatLng(lat, lng),
          topic: topic,
          organizer: organizer,
          scenario: scenario,
          badges: badgesByEventId[eventId] ?? <String>[],
        );
      }).where((EventPin item) {
        final bool queryMatch = normalizedQuery.isEmpty ||
            item.title.toLowerCase().contains(normalizedQuery) ||
            item.subtitle.toLowerCase().contains(normalizedQuery);
        final bool topicMatch = topicSet.isEmpty || topicSet.contains(item.topic);
        return queryMatch && topicMatch;
      }).toList(growable: false);

      return pins;
    } on PostgrestException catch (e) {
      throw Exception('Blad bazy danych podczas pobierania wydarzen: ${e.message}');
    } catch (_) {
      throw Exception('Blad polaczenia: Nie udalo sie pobrac wydarzen.');
    }
  }

  @override
  Future<void> joinEvent(String eventId) async {
    // TODO: zaimplementuj dołączanie do wydarzenia
  }

  @override
  Future<void> askQuestion(String eventId, String question) async {
    // TODO: zaimplementuj wysyłanie pytania
  }

  @override
  Future<void> reportLocal(String eventId) async {
    // TODO: zaimplementuj zgłaszanie lokalne
  }

  /// Wstawia nowe wydarzenie do tabeli `events`.
  ///
  /// Współrzędne [model.Event.lat] i [model.Event.lng] są konwertowane
  /// do formatu PostGIS WKT: `POINT(lng lat)` (X=lng, Y=lat zgodnie ze standardem).
  /// Jeśli w tabeli istnieje kolumna typu `geography(POINT, 4326)`, odkomentuj
  /// pole `location` w poniższym insert.
  ///
  /// Rzuca [Exception] z polskim komunikatem przy błędzie bazy lub połączenia.
  @override
  Future<void> createEvent(model.Event event,
      {List<String> badges = const <String>[]}) async {
    // WKT dla PostGIS – gotowe gdy dodasz kolumnę geography(POINT,4326)
    final String pointWkt = 'POINT(${event.lng} ${event.lat})';

    try {
      // .select('id') zwraca uuid wstawionego wiersza potrzebny do odznak
      final List<dynamic> inserted =
          await _client.from('events').insert(<String, dynamic>{
        'title': event.title,
        if (event.subtitle != null) 'subtitle': event.subtitle,
        if (event.description != null) 'description': event.description,
        'scenario': event.scenario.name,
        'status': event.status.name,
        'organizer_id': event.organizerId,
        'lat': event.lat,
        'lng': event.lng,
        // 'location': pointWkt, // odkomentuj po: ALTER TABLE events ADD COLUMN location geography(POINT,4326);
        'city': event.city,
        if (event.startsAt != null)
          'starts_at': event.startsAt!.toIso8601String(),
        if (event.endsAt != null) 'ends_at': event.endsAt!.toIso8601String(),
        if (event.photoUrl != null) 'photo_url': event.photoUrl,
      }).select('id');

      // Wstaw odznaki do event_badges jeśli podano
      if (badges.isNotEmpty && inserted.isNotEmpty) {
        final String eventId =
            (inserted.first as Map<String, dynamic>)['id'] as String;
        await _client.from('event_badges').insert(
          badges
              .map<Map<String, dynamic>>(
                (String badge) => <String, dynamic>{
                  'event_id': eventId,
                  'badge_code': badge.toLowerCase().replaceAll(' ', '_'),
                  'badge_label': badge,
                },
              )
              .toList(growable: false),
        );
      }
    } on PostgrestException catch (e) {
      throw Exception('Błąd bazy danych: ${e.message}');
    } catch (_) {
      throw Exception('Błąd połączenia: Nie udało się zapisać wydarzenia.');
    }

    assert(pointWkt.isNotEmpty);
  }
}
