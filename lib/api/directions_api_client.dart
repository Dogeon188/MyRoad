import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:myroad/api/api_keys.dart';

class DirectionsLeg {
  final int durationMinutes;
  final double distanceMeters;
  final String? polyline;
  final String? routeName;
  final String mode;

  DirectionsLeg({
    required this.durationMinutes,
    required this.distanceMeters,
    this.polyline,
    this.routeName,
    required this.mode,
  });
}

/// One route option (may contain multiple legs for transit).
class RouteOption {
  final int totalDurationMinutes;
  final double totalDistanceMeters;
  final String summary;
  final List<DirectionsLeg> legs;

  RouteOption({
    required this.totalDurationMinutes,
    required this.totalDistanceMeters,
    required this.summary,
    required this.legs,
  });
}

class DirectionsApiClient {
  final http.Client _client;

  DirectionsApiClient({http.Client? client})
    : _client = client ?? http.Client();

  static const _routesBaseUrl =
      'https://routes.googleapis.com/directions/v2:computeRoutes';
  static const _directionsBaseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  static const _travelModeMap = {
    'walk': 'WALK',
    'transit': 'TRANSIT',
    'car': 'DRIVE',
    'driving': 'DRIVE',
  };

  /// Returns available route options. Each option has one or more legs.
  Future<List<RouteOption>> getRoutes({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String mode,
    DateTime? departTime,
    DateTime? arrivalTime,
  }) async {
    if (mode == 'transit') {
      final results = await _getTransitRoutesV2(
        originLat,
        originLng,
        destLat,
        destLng,
        departTime: departTime,
        arrivalTime: arrivalTime,
      );
      if (results.isNotEmpty) return results;
      return _getTransitRoutesLegacy(
        originLat,
        originLng,
        destLat,
        destLng,
        departTime: departTime,
        arrivalTime: arrivalTime,
      );
    }
    if (mode == 'bicycle') {
      return _getBicycleRoutesLegacy(originLat, originLng, destLat, destLng);
    }
    return _getRoutesV2(originLat, originLng, destLat, destLng, mode);
  }

  /// Routes API v2 for walk/drive/bicycle.
  Future<List<RouteOption>> _getRoutesV2(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
    String mode,
  ) async {
    final travelMode = _travelModeMap[mode] ?? 'DRIVE';
    final body = {
      'origin': {
        'location': {
          'latLng': {'latitude': originLat, 'longitude': originLng},
        },
      },
      'destination': {
        'location': {
          'latLng': {'latitude': destLat, 'longitude': destLng},
        },
      },
      'travelMode': travelMode,
      'polylineEncoding': 'ENCODED_POLYLINE',
      'computeAlternativeRoutes': false,
    };

    final response = await _client.post(
      Uri.parse(_routesBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': ApiKeys.placesApiKey,
        'X-Goog-FieldMask':
            'routes.duration,routes.distanceMeters,routes.polyline',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return [];

    return routes.map((route) {
      final dur = _parseDurationSeconds(route['duration']);
      final dist = (route['distanceMeters'] as num?)?.toDouble() ?? 0;
      return RouteOption(
        totalDurationMinutes: dur,
        totalDistanceMeters: dist,
        summary: _formatDistance(dist),
        legs: [
          DirectionsLeg(
            durationMinutes: dur,
            distanceMeters: dist,
            polyline: route['polyline']?['encodedPolyline'] as String?,
            mode: mode,
          ),
        ],
      );
    }).toList();
  }

  /// Routes API v2 for transit.
  Future<List<RouteOption>> _getTransitRoutesV2(
    double originLat,
    double originLng,
    double destLat,
    double destLng, {
    DateTime? departTime,
    DateTime? arrivalTime,
  }) async {
    final body = {
      'origin': {
        'location': {
          'latLng': {'latitude': originLat, 'longitude': originLng},
        },
      },
      'destination': {
        'location': {
          'latLng': {'latitude': destLat, 'longitude': destLng},
        },
      },
      'travelMode': 'TRANSIT',
      if (arrivalTime != null)
        'arrivalTime': arrivalTime.toUtc().toIso8601String()
      else if (departTime != null)
        'departureTime': departTime.toUtc().toIso8601String(),
    };

    final response = await _client.post(
      Uri.parse(_routesBaseUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': ApiKeys.placesApiKey,
        'X-Goog-FieldMask': 'routes.legs,routes.duration,routes.distanceMeters',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return [];

    return routes
        .map((route) {
          final routeLegs = route['legs'] as List? ?? [];
          if (routeLegs.isEmpty) return null;

          final apiLeg = routeLegs[0];
          final totalDur = _parseDurationSeconds(apiLeg['duration']);
          final totalDist = (apiLeg['distanceMeters'] as num?)?.toDouble() ?? 0;

          final steps = apiLeg['steps'] as List?;
          if (steps == null || steps.isEmpty) {
            return RouteOption(
              totalDurationMinutes: totalDur,
              totalDistanceMeters: totalDist,
              summary: '${totalDur}min',
              legs: [
                DirectionsLeg(
                  durationMinutes: totalDur,
                  distanceMeters: totalDist,
                  mode: 'transit',
                ),
              ],
            );
          }

          final legs = <DirectionsLeg>[];
          final transitNames = <String>[];

          for (final step in steps) {
            final stepMode = step['travelMode'] as String?;
            final transit = step['transitDetails'];
            String resultMode;
            String? routeName;

            if (stepMode == 'TRANSIT' && transit != null) {
              resultMode = 'transit';
              final line = transit['transitLine'];
              routeName =
                  line?['nameShort'] as String? ?? line?['name'] as String?;
              if (routeName != null) transitNames.add(routeName);
            } else {
              resultMode = 'walk';
            }

            legs.add(
              DirectionsLeg(
                durationMinutes: _parseDurationSeconds(step['staticDuration']),
                distanceMeters:
                    (step['distanceMeters'] as num?)?.toDouble() ?? 0,
                polyline: step['polyline']?['encodedPolyline'] as String?,
                routeName: routeName,
                mode: resultMode,
              ),
            );
          }

          return RouteOption(
            totalDurationMinutes: totalDur,
            totalDistanceMeters: totalDist,
            summary: transitNames.isEmpty
                ? '${totalDur}min'
                : '${transitNames.join(' → ')} (${totalDur}min)',
            legs: legs,
          );
        })
        .whereType<RouteOption>()
        .toList();
  }

  /// Legacy Directions API fallback for transit (covers Japan etc.).
  Future<List<RouteOption>> _getTransitRoutesLegacy(
    double originLat,
    double originLng,
    double destLat,
    double destLng, {
    DateTime? departTime,
    DateTime? arrivalTime,
  }) async {
    final uri = Uri.parse(_directionsBaseUrl).replace(
      queryParameters: {
        'origin': '$originLat,$originLng',
        'destination': '$destLat,$destLng',
        'mode': 'transit',
        'alternatives': 'true',
        'key': ApiKeys.placesApiKey,
        if (arrivalTime != null)
          'arrival_time': '${arrivalTime.millisecondsSinceEpoch ~/ 1000}'
        else if (departTime != null)
          'departure_time': '${departTime.millisecondsSinceEpoch ~/ 1000}',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return [];

    return routes
        .map((route) {
          final apiLeg = (route['legs'] as List)[0];
          final totalDur = (apiLeg['duration']['value'] as int) ~/ 60;
          final totalDist = (apiLeg['distance']['value'] as int).toDouble();

          final steps = apiLeg['steps'] as List;
          final legs = <DirectionsLeg>[];
          final transitNames = <String>[];

          for (final step in steps) {
            final stepMode = step['travel_mode'] as String?;
            final transit = step['transit_details'];
            String resultMode;
            String? routeName;

            if (stepMode == 'TRANSIT' && transit != null) {
              resultMode = 'transit';
              final line = transit['line'];
              routeName =
                  line?['short_name'] as String? ?? line?['name'] as String?;
              if (routeName != null) transitNames.add(routeName);
            } else {
              resultMode = 'walk';
            }

            legs.add(
              DirectionsLeg(
                durationMinutes: ((step['duration']['value'] as int) / 60)
                    .ceil(),
                distanceMeters: (step['distance']['value'] as int).toDouble(),
                polyline: step['polyline']?['points'] as String?,
                routeName: routeName,
                mode: resultMode,
              ),
            );
          }

          return RouteOption(
            totalDurationMinutes: totalDur,
            totalDistanceMeters: totalDist,
            summary: transitNames.isEmpty
                ? '${totalDur}min'
                : '${transitNames.join(' → ')} (${totalDur}min)',
            legs: legs,
          );
        })
        .cast<RouteOption>()
        .toList();
  }

  /// Legacy Directions API for bicycle (Routes API v2 TWO_WHEELER only works in select regions).
  Future<List<RouteOption>> _getBicycleRoutesLegacy(
    double originLat,
    double originLng,
    double destLat,
    double destLng,
  ) async {
    final uri = Uri.parse(_directionsBaseUrl).replace(
      queryParameters: {
        'origin': '$originLat,$originLng',
        'destination': '$destLat,$destLng',
        'mode': 'bicycling',
        'alternatives': 'true',
        'key': ApiKeys.placesApiKey,
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final routes = data['routes'] as List?;
    if (routes == null || routes.isEmpty) return [];

    final results = routes
        .map((route) {
          final apiLeg = (route['legs'] as List)[0];
          final totalDur = (apiLeg['duration']['value'] as int) ~/ 60;
          final totalDist = (apiLeg['distance']['value'] as int).toDouble();

          return RouteOption(
            totalDurationMinutes: totalDur,
            totalDistanceMeters: totalDist,
            summary: _formatDistance(totalDist),
            legs: [
              DirectionsLeg(
                durationMinutes: totalDur,
                distanceMeters: totalDist,
                polyline: route['overview_polyline']?['points'] as String?,
                mode: 'bicycle',
              ),
            ],
          );
        })
        .cast<RouteOption>()
        .toList();
    return results;
  }

  /// Parses Routes API v2 duration format ("123s").
  static int _parseDurationSeconds(dynamic d) {
    if (d == null) return 0;
    if (d is String) {
      final s = d.replaceAll('s', '');
      return ((int.tryParse(s) ?? 0) / 60).ceil();
    }
    return 0;
  }

  static String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}
