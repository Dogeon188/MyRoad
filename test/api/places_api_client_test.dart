import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/api/places_api_client.dart';

void main() {
  test('extractPlaceIdFromUrl parses cid URL', () {
    final id = PlacesApiClient.extractPlaceIdFromUrl(
        'https://maps.google.com/?cid=12345');
    expect(id, '12345');
  });

  test('extractPlaceIdFromUrl parses place_id URL', () {
    final id = PlacesApiClient.extractPlaceIdFromUrl(
        'https://maps.google.com/?place_id=ChIJ123abc');
    expect(id, 'ChIJ123abc');
  });

  test('extractPlaceIdFromUrl returns null for unknown format', () {
    final id = PlacesApiClient.extractPlaceIdFromUrl('https://example.com');
    expect(id, isNull);
  });
}
