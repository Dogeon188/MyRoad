import 'package:flutter_test/flutter_test.dart';

void main() {
  final placeIdRegex = RegExp(r'place_id=([A-Za-z0-9_-]+)');
  final placeNameRegex = RegExp(r'/maps/place/([^/@]+)');

  test('regex extracts place_id from URL', () {
    final match = placeIdRegex.firstMatch(
      'https://maps.google.com/?place_id=ChIJ123abc',
    );
    expect(match?.group(1), 'ChIJ123abc');
  });

  test('regex extracts place name from path', () {
    final match = placeNameRegex.firstMatch(
      'https://www.google.com/maps/place/Golden+Gai/@35.69,-139.70',
    );
    expect(
      Uri.decodeComponent(match!.group(1)!.replaceAll('+', ' ')),
      'Golden Gai',
    );
  });

  test('Uri extracts q param from maps.google.com redirect', () {
    final uri = Uri.parse(
      'https://maps.google.com/maps?q=GiGO+Hiroshima&ftid=0x355aa20f:0x7b0cdd58',
    );
    expect(uri.queryParameters['q'], 'GiGO Hiroshima');
  });

  test('regex returns null for unknown format', () {
    final pidMatch = placeIdRegex.firstMatch('https://example.com');
    final nameMatch = placeNameRegex.firstMatch('https://example.com');
    expect(pidMatch, isNull);
    expect(nameMatch, isNull);
  });
}
