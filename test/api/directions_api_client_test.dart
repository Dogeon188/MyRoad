import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/api/directions_api_client.dart';

void main() {
  test('DirectionsResult stores values', () {
    final result = DirectionsResult(
      durationMinutes: 15,
      distanceMeters: 1200,
      polyline: 'abc123',
    );
    expect(result.durationMinutes, 15);
    expect(result.distanceMeters, 1200);
    expect(result.polyline, 'abc123');
  });
}
