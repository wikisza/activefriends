import 'package:activefriends/src/features/map/data/event_api_client.dart';
import 'package:activefriends/src/features/map/domain/event_models.dart';

abstract class EventRepository {
  Future<List<EventPin>> fetchPins({
    String? query,
    List<String>? topics,
  });

  Future<void> joinEvent(String eventId);

  Future<void> askQuestion(String eventId, String question);

  Future<void> reportLocal(String eventId);
}

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
}
