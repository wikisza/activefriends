import 'dart:convert';

import 'package:activefriends/src/features/map/domain/event_models.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class EventApiClient {
  EventApiClient({required this.baseUrl, required this.httpClient});

  final String baseUrl;
  final http.Client httpClient;

  Future<List<EventPin>> fetchPins({
    String? query,
    List<String>? topics,
  }) async {
    final uri = Uri.parse('$baseUrl/events').replace(
      queryParameters: <String, String>{
        if (query != null && query.trim().isNotEmpty) 'query': query,
        if (topics != null && topics.isNotEmpty) 'topics': topics.join(','),
      },
    );

    final response = await httpClient.get(uri);
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw Exception('fetchPins failed with status ${response.statusCode}');
    }

    final dynamic decoded = jsonDecode(response.body);
    final List<dynamic> rows = (decoded is Map<String, dynamic>)
        ? (decoded['data'] as List<dynamic>? ?? <dynamic>[])
        : (decoded as List<dynamic>? ?? <dynamic>[]);

    return rows
        .whereType<Map<String, dynamic>>()
        .map(_mapEvent)
        .toList(growable: false);
  }

  Future<void> joinEvent(String eventId, {String role = 'member'}) async {
    await _post('/events/$eventId/join', <String, dynamic>{'role': role});
  }

  Future<void> askQuestion(String eventId, String question) async {
    await _post('/events/$eventId/questions', <String, dynamic>{
      'question': question,
    });
  }

  Future<void> reportLocal(String eventId) async {
    await _post('/events/$eventId/report-local', const <String, dynamic>{});
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final response = await httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode > 299) {
      throw Exception('POST $path failed with status ${response.statusCode}');
    }
  }

  EventPin _mapEvent(Map<String, dynamic> row) {
    final String scenarioRaw = (row['scenario'] as String? ?? '').toLowerCase();
    final EventScenario scenario = switch (scenarioRaw) {
      'emergency' => EventScenario.emergency,
      'social' => EventScenario.social,
      _ => EventScenario.bikeRide,
    };

    final String verificationRaw = (row['verificationLevel'] as String? ?? '')
        .toLowerCase();
    final VerificationLevel level = switch (verificationRaw) {
      'level3' => VerificationLevel.level3,
      'level2' => VerificationLevel.level2,
      _ => VerificationLevel.level1,
    };

    final double lat = (row['lat'] as num?)?.toDouble() ?? 53.1235;
    final double lng = (row['lng'] as num?)?.toDouble() ?? 18.0084;

    final List<dynamic> badgesRaw =
        row['badges'] as List<dynamic>? ?? <dynamic>[];

    return EventPin(
      id: row['id']?.toString() ?? 'unknown',
      title: row['title']?.toString() ?? 'Bez nazwy',
      subtitle: row['subtitle']?.toString() ?? '',
      location: LatLng(lat, lng),
      topic: row['topic']?.toString() ?? 'Inne',
      organizer: UserProfile(
        id: row['organizerId']?.toString() ?? 'unknown',
        displayName: row['organizerName']?.toString() ?? 'Organizator',
        verificationLevel: level,
      ),
      scenario: scenario,
      badges: badgesRaw
          .map((dynamic e) => e.toString())
          .toList(growable: false),
      photoLabel: row['photoLabel']?.toString(),
    );
  }
}
