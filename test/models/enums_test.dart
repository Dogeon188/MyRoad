import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/models/enums.dart';

void main() {
  test('TransportMode round-trips from string', () {
    for (final mode in TransportMode.values) {
      expect(TransportMode.fromString(mode.value), mode);
    }
  });

  test('SpotType round-trips from string', () {
    for (final type in SpotType.values) {
      expect(SpotType.fromString(type.value), type);
    }
  });

  test('RegionType round-trips from string', () {
    for (final type in RegionType.values) {
      expect(RegionType.fromString(type.value), type);
    }
  });

  test('PlanMode round-trips from string', () {
    for (final mode in PlanMode.values) {
      expect(PlanMode.fromString(mode.value), mode);
    }
  });
}
