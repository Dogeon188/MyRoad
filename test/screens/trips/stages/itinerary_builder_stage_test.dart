import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/screens/trips/stages/itinerary_builder_stage.dart';

void main() {
  final tripStart = DateTime(2026, 7, 1);

  test('centers offset on today\'s column within trip range', () {
    final offset = todayScrollOffset(
      startDate: tripStart,
      dayCount: 5,
      today: DateTime(2026, 7, 3), // day 3 of 5
      viewportWidth: 600,
      maxScrollExtent: 1000,
    );
    // day index 2 * 200 - (600 - 200) / 2 = 400 - 200 = 200
    expect(offset, 200);
  });

  test('returns null when today is before the trip', () {
    final offset = todayScrollOffset(
      startDate: tripStart,
      dayCount: 5,
      today: DateTime(2026, 6, 30),
      viewportWidth: 600,
      maxScrollExtent: 1000,
    );
    expect(offset, isNull);
  });

  test('returns null when today is after the trip', () {
    final offset = todayScrollOffset(
      startDate: tripStart,
      dayCount: 5,
      today: DateTime(2026, 7, 10),
      viewportWidth: 600,
      maxScrollExtent: 1000,
    );
    expect(offset, isNull);
  });

  test('clamps to maxScrollExtent on the last day with a wide viewport', () {
    final offset = todayScrollOffset(
      startDate: tripStart,
      dayCount: 5,
      today: DateTime(2026, 7, 5), // day 5 of 5
      viewportWidth: 900,
      maxScrollExtent: 300,
    );
    expect(offset, 300);
  });
}
