import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  RouteService({required this.httpClient});

  final http.Client httpClient;

  Future<List<LatLng>> fetchBikeRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final Uri uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/bicycle/'
      '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await httpClient.get(uri);
      if (response.statusCode < 200 || response.statusCode > 299) {
        return <LatLng>[start, end];
      }

      final dynamic decoded = jsonDecode(response.body);
      final List<dynamic>? routes = (decoded is Map<String, dynamic>)
          ? decoded['routes'] as List<dynamic>?
          : null;
      if (routes == null || routes.isEmpty) {
        return <LatLng>[start, end];
      }

      final Map<String, dynamic> route = routes.first as Map<String, dynamic>;
      final Map<String, dynamic>? geometry =
          route['geometry'] as Map<String, dynamic>?;
      final List<dynamic>? coordinates =
          geometry?['coordinates'] as List<dynamic>?;
      if (coordinates == null || coordinates.isEmpty) {
        return <LatLng>[start, end];
      }

      return coordinates
          .whereType<List<dynamic>>()
          .where((List<dynamic> item) => item.length >= 2)
          .map((List<dynamic> item) {
        final double lng = (item[0] as num).toDouble();
        final double lat = (item[1] as num).toDouble();
        return LatLng(lat, lng);
      }).toList(growable: false);
    } catch (_) {
      return <LatLng>[start, end];
    }
  }
}
