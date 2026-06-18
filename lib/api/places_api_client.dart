import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:myroad/api/api_keys.dart';

class PlaceSearchResult {
  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;

  PlaceSearchResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
}

class PlaceOpeningHoursPeriod {
  final int day;
  final int openMinutes;
  final int closeMinutes;

  PlaceOpeningHoursPeriod({
    required this.day,
    required this.openMinutes,
    required this.closeMinutes,
  });
}

class PlaceDetails {
  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final List<PlaceOpeningHoursPeriod> openingHours;
  final List<String> photoReferences;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.openingHours,
    required this.photoReferences,
  });
}

class PlacesApiClient {
  final http.Client _client;
  static const _baseUrl = 'https://places.googleapis.com/v1/places';

  PlacesApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<List<PlaceSearchResult>> searchText(String query) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl:searchText'),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': ApiKeys.placesApiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,places.location',
      },
      body: jsonEncode({'textQuery': query}),
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final places = data['places'] as List? ?? [];
    return places
        .map((p) => PlaceSearchResult(
              placeId: p['id'] as String,
              name: (p['displayName']?['text'] as String?) ?? '',
              address: (p['formattedAddress'] as String?) ?? '',
              lat: (p['location']?['latitude'] as num?)?.toDouble() ?? 0,
              lng: (p['location']?['longitude'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/$placeId'),
      headers: {
        'X-Goog-Api-Key': ApiKeys.placesApiKey,
        'X-Goog-FieldMask': 'id,displayName,formattedAddress,location,'
            'currentOpeningHours.periods,photos',
      },
    );

    if (response.statusCode != 200) return null;

    final p = jsonDecode(response.body);
    final periods = (p['currentOpeningHours']?['periods'] as List? ?? [])
        .map((period) {
      final open = period['open'];
      final close = period['close'];
      return PlaceOpeningHoursPeriod(
        day: (open?['day'] as int?) ?? 0,
        openMinutes:
            ((open?['hour'] as int?) ?? 0) * 60 + ((open?['minute'] as int?) ?? 0),
        closeMinutes:
            ((close?['hour'] as int?) ?? 0) * 60 + ((close?['minute'] as int?) ?? 0),
      );
    }).toList();

    final photos = (p['photos'] as List? ?? [])
        .map((photo) => photo['name'] as String)
        .toList();

    return PlaceDetails(
      placeId: p['id'] as String,
      name: (p['displayName']?['text'] as String?) ?? '',
      address: (p['formattedAddress'] as String?) ?? '',
      lat: (p['location']?['latitude'] as num?)?.toDouble() ?? 0,
      lng: (p['location']?['longitude'] as num?)?.toDouble() ?? 0,
      openingHours: periods,
      photoReferences: photos,
    );
  }

  String getPhotoUrl(String photoReference, {int maxWidth = 400}) {
    return '$_baseUrl/$photoReference/media?maxWidthPx=$maxWidth&key=${ApiKeys.placesApiKey}';
  }

  Future<PlaceSearchResult?> resolveFromUrl(String url) async {
    var resolved = url;

    if (RegExp(r'goo\.gl|maps\.app').hasMatch(url)) {
      final request = http.Request('GET', Uri.parse(url))
        ..followRedirects = false;
      final response = await _client.send(request);
      resolved = response.headers['location'] ?? url;
    }

    // Try direct place_id param
    final pidMatch =
        RegExp(r'place_id=([A-Za-z0-9_-]+)').firstMatch(resolved);
    if (pidMatch != null) {
      final details = await getPlaceDetails(pidMatch.group(1)!);
      if (details != null) return _detailsToResult(details);
    }

    // Parse place name from path: /maps/place/Place+Name/@lat,lng,...
    final pathMatch =
        RegExp(r'/maps/place/([^/@]+)').firstMatch(resolved);
    if (pathMatch != null) {
      final name = Uri.decodeComponent(pathMatch.group(1)!.replaceAll('+', ' '));
      final results = await searchText(name);
      if (results.isNotEmpty) return results.first;
    }

    return null;
  }

  PlaceSearchResult _detailsToResult(PlaceDetails d) => PlaceSearchResult(
        placeId: d.placeId,
        name: d.name,
        address: d.address,
        lat: d.lat,
        lng: d.lng,
      );
}
