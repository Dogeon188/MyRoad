import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:myroad/api/api_keys.dart';

class DirectionsResult {
  final int durationMinutes;
  final double distanceMeters;
  final String? polyline;

  DirectionsResult({
    required this.durationMinutes,
    required this.distanceMeters,
    this.polyline,
  });
}

class DirectionsApiClient {
  final http.Client _client;
  static const _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  DirectionsApiClient({http.Client? client})
      : _client = client ?? http.Client();

  static const _modeMap = {
    'walk': 'walking',
    'transit': 'transit',
    'driving': 'driving',
    'motorcycle': 'driving',
  };

  Future<DirectionsResult?> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String mode,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'origin': '$originLat,$originLng',
      'destination': '$destLat,$destLng',
      'mode': _modeMap[mode] ?? 'driving',
      'key': ApiKeys.placesApiKey,
    });

    var response = await _client.get(uri);
    if (response.statusCode != 200) return null;

    var data = jsonDecode(response.body);
    var status = data['status'];
    var routes = data['routes'] as List?;

    // Fallback: if ZERO_RESULTS, retry with DRIVING
    if (status == 'ZERO_RESULTS' && (_modeMap[mode] ?? 'driving') != 'driving') {
      final fallbackUri = Uri.parse(_baseUrl).replace(queryParameters: {
        'origin': '$originLat,$originLng',
        'destination': '$destLat,$destLng',
        'mode': 'driving',
        'key': ApiKeys.placesApiKey,
      });
      response = await _client.get(fallbackUri);
      if (response.statusCode != 200) return null;
      data = jsonDecode(response.body);
      routes = data['routes'] as List?;
    }

    if (routes == null || routes.isEmpty) return null;

    final leg = routes[0]['legs'][0];
    return DirectionsResult(
      durationMinutes: ((leg['duration']['value'] as int) / 60).ceil(),
      distanceMeters: (leg['distance']['value'] as int).toDouble(),
      polyline: routes[0]['overview_polyline']?['points'] as String?,
    );
  }
}
