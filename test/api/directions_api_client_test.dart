import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/api/directions_api_client.dart';

void main() {
  test('DirectionsLeg stores values', () {
    final leg = DirectionsLeg(
      durationMinutes: 15,
      distanceMeters: 1200,
      polyline: 'abc123',
      mode: 'walk',
    );
    expect(leg.durationMinutes, 15);
    expect(leg.distanceMeters, 1200);
    expect(leg.polyline, 'abc123');
    expect(leg.mode, 'walk');
  });

  test('RouteOption contains legs', () {
    final option = RouteOption(
      totalDurationMinutes: 30,
      totalDistanceMeters: 2500,
      summary: '2.5 km',
      legs: [
        DirectionsLeg(durationMinutes: 30, distanceMeters: 2500, mode: 'car'),
      ],
    );
    expect(option.legs.length, 1);
    expect(option.totalDurationMinutes, 30);
  });
}
