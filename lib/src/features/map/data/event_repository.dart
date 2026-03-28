import 'package:activefriends/src/features/map/data/event_api_client.dart';
import 'package:activefriends/src/features/map/domain/event_models.dart';
import 'package:activefriends/src/models/event.dart' as model;
import 'package:activefriends/src/models/topic_catalog.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class EventRepository {
  Future<List<EventPin>> fetchPins({String? query, List<String>? topics});

  Future<void> joinEvent(String eventId, {String role});

  Future<void> askQuestion(String eventId, String question);

  Future<void> reportLocal(String eventId);

  /// Wstawia nowe wydarzenie do tabeli `events`.
  /// Wymaga zalogowanego użytkownika (auth.uid() = organizer_id).
  /// [badges] – opcjonalna lista odznak (PILNE, TYLKO ZWERYFIKOWANI itp.)
  /// zapisywanych do tabeli `event_badges`.
  Future<void> createEvent(
    model.Event event, {
    List<String> badges = const <String>[],
  });
}

// ---------------------------------------------------------------------------
// HTTP-based implementation (legacy)
// ---------------------------------------------------------------------------

class ApiEventRepository implements EventRepository {
  ApiEventRepository({required this.apiClient});

  final EventApiClient apiClient;

  @override
  Future<List<EventPin>> fetchPins({String? query, List<String>? topics}) {
    return apiClient.fetchPins(query: query, topics: topics);
  }

  @override
  Future<void> joinEvent(String eventId, {String role = 'member'}) {
    return apiClient.joinEvent(eventId, role: role);
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
  Future<void> createEvent(
    model.Event event, {
    List<String> badges = const <String>[],
  }) {
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
          .select(
            'id,title,subtitle,scenario,organizer_id,lat,lng,starts_at,ends_at',
          )
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
          final int levelRaw =
              (row['verification_level'] as num?)?.toInt() ?? 1;
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

      final String? currentUserId = _client.auth.currentUser?.id;
      final Map<String, String> participationRoleByEventId = <String, String>{};
      if (currentUserId != null && eventIds.isNotEmpty) {
        final List<dynamic> rawParticipants = await _client
            .from('event_participants')
            .select('event_id,role')
            .eq('profile_id', currentUserId)
            .inFilter('event_id', eventIds.toList(growable: false));

        for (final Map<String, dynamic> row
            in rawParticipants.whereType<Map<String, dynamic>>()) {
          final String eventId = row['event_id']?.toString() ?? '';
          final String role = row['role']?.toString() ?? '';
          if (eventId.isEmpty || role.isEmpty) {
            continue;
          }
          participationRoleByEventId[eventId] = role;
        }
      }

      final Map<String, List<String>> badgesByEventId =
          <String, List<String>>{};
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

      final List<EventPin> pins = events
          .map((Map<String, dynamic> row) {
            final String scenarioRaw = row['scenario']?.toString() ?? '';
            final EventScenario scenario = switch (scenarioRaw) {
              'emergency' => EventScenario.emergency,
              'social' => EventScenario.social,
              _ => EventScenario.bikeRide,
            };

            final String topic = primaryTopicForScenarioKey(scenarioRaw);

            final String eventId = row['id']?.toString() ?? 'unknown';
            final String organizerId =
                row['organizer_id']?.toString() ?? 'unknown';
            final String organizerFallback = organizerId.length > 8
                ? 'Uzytkownik ${organizerId.substring(0, 8)}'
                : 'Uzytkownik';
            final UserProfile organizer =
                organizersById[organizerId] ??
                UserProfile(
                  id: organizerId,
                  displayName: organizerFallback,
                  verificationLevel: VerificationLevel.level1,
                );

            final double lat = (row['lat'] as num?)?.toDouble() ?? 53.1235;
            final double lng = (row['lng'] as num?)?.toDouble() ?? 18.0084;
            final DateTime? startsAt = row['starts_at'] != null
                ? DateTime.tryParse(row['starts_at'].toString())
                : null;
            final DateTime? endsAt = row['ends_at'] != null
                ? DateTime.tryParse(row['ends_at'].toString())
                : null;

            return EventPin(
              id: eventId,
              title: row['title']?.toString() ?? 'Bez nazwy',
              subtitle: row['subtitle']?.toString() ?? 'Brak opisu',
              location: LatLng(lat, lng),
              topic: topic,
              organizer: organizer,
              scenario: scenario,
              badges: badgesByEventId[eventId] ?? <String>[],
              startsAt: startsAt,
              endsAt: endsAt,
              participationRole: participationRoleByEventId[eventId],
            );
          })
          .where((EventPin item) {
            final bool queryMatch =
                normalizedQuery.isEmpty ||
                item.title.toLowerCase().contains(normalizedQuery) ||
                item.subtitle.toLowerCase().contains(normalizedQuery);
            final String scenarioKey = switch (item.scenario) {
              EventScenario.emergency => 'emergency',
              EventScenario.social => 'social',
              EventScenario.bikeRide => 'bikeRide',
            };
            final bool topicMatch = matchesTopicFilters(
              selectedTopics: topicSet,
              scenarioKey: scenarioKey,
              fallbackTopic: item.topic,
            );
            return queryMatch && topicMatch;
          })
          .toList(growable: false);

      return pins;
    } on PostgrestException catch (e) {
      throw Exception(
        'Blad bazy danych podczas pobierania wydarzen: ${e.message}',
      );
    } catch (_) {
      throw Exception('Blad polaczenia: Nie udalo sie pobrac wydarzen.');
    }
  }

  @override
  Future<void> joinEvent(String eventId, {String role = 'member'}) async {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Musisz być zalogowany, aby dołączyć do wydarzenia.');
    }

    final String normalizedRole = switch (role) {
      'helper' => 'helper',
      'organizer' => 'organizer',
      _ => 'member',
    };

    try {
      final Map<String, dynamic>? eventRow = await _client
          .from('events')
          .select('id,organizer_id')
          .eq('id', eventId)
          .maybeSingle();

      if (eventRow == null) {
        throw Exception('To wydarzenie już nie istnieje.');
      }

      final String organizerId = eventRow['organizer_id']?.toString() ?? '';
      if (organizerId == user.id) {
        throw Exception('Jesteś organizatorem tego wydarzenia.');
      }

      final Map<String, dynamic>? existingParticipant = await _client
          .from('event_participants')
          .select('role')
          .eq('event_id', eventId)
          .eq('profile_id', user.id)
          .maybeSingle();

      if (existingParticipant != null) {
        final String existingRole =
            existingParticipant['role']?.toString() ?? normalizedRole;
        if (existingRole == normalizedRole) {
          throw Exception('Już dołączyłeś do tego wydarzenia.');
        }

        await _client
            .from('event_participants')
            .update(<String, dynamic>{'role': normalizedRole})
            .eq('event_id', eventId)
            .eq('profile_id', user.id);
        return;
      }

      await _client.from('event_participants').insert(<String, dynamic>{
        'event_id': eventId,
        'profile_id': user.id,
        'role': normalizedRole,
      });
    } on PostgrestException catch (e) {
      throw Exception('Błąd bazy danych podczas dołączania: ${e.message}');
    }
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
  Future<void> createEvent(
    model.Event event, {
    List<String> badges = const <String>[],
  }) async {
    // WKT dla PostGIS – gotowe gdy dodasz kolumnę geography(POINT,4326)
    final String pointWkt = 'POINT(${event.lng} ${event.lat})';

    try {
      // .select('id') zwraca uuid wstawionego wiersza potrzebny do odznak
      final List<dynamic> inserted = await _client
          .from('events')
          .insert(<String, dynamic>{
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
            if (event.endsAt != null)
              'ends_at': event.endsAt!.toIso8601String(),
            if (event.photoUrl != null) 'photo_url': event.photoUrl,
          })
          .select('id');

      // Wstaw odznaki do event_badges jeśli podano
      if (badges.isNotEmpty && inserted.isNotEmpty) {
        final String eventId =
            (inserted.first as Map<String, dynamic>)['id'] as String;
        await _client.from('event_participants').insert(<String, dynamic>{
          'event_id': eventId,
          'profile_id': event.organizerId,
          'role': 'organizer',
        });
        await _client
            .from('event_badges')
            .insert(
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
      } else if (inserted.isNotEmpty) {
        final String eventId =
            (inserted.first as Map<String, dynamic>)['id'] as String;
        await _client.from('event_participants').insert(<String, dynamic>{
          'event_id': eventId,
          'profile_id': event.organizerId,
          'role': 'organizer',
        });
      }
    } on PostgrestException catch (e) {
      throw Exception('Błąd bazy danych: ${e.message}');
    } catch (_) {
      throw Exception('Błąd połączenia: Nie udało się zapisać wydarzenia.');
    }

    assert(pointWkt.isNotEmpty);
  }
}
