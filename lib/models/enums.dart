enum TransportMode {
  walk('walk'),
  transit('transit'),
  car('car'),
  motorcycle('motorcycle');

  const TransportMode(this.value);
  final String value;

  static TransportMode fromString(String s) =>
      values.firstWhere((e) => e.value == s);
}

enum SpotType {
  spot('spot'),
  restaurant('restaurant'),
  hotel('hotel'),
  custom('custom');

  const SpotType(this.value);
  final String value;

  static SpotType fromString(String s) =>
      values.firstWhere((e) => e.value == s);
}

enum RegionType {
  country('country'),
  city('city'),
  neighborhood('neighborhood');

  const RegionType(this.value);
  final String value;

  static RegionType fromString(String s) =>
      values.firstWhere((e) => e.value == s);
}

enum PlanMode {
  coarse('coarse'),
  detailed('detailed');

  const PlanMode(this.value);
  final String value;

  static PlanMode fromString(String s) =>
      values.firstWhere((e) => e.value == s);
}
