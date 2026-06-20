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
  online('online'),
  custom('custom');

  const SpotType(this.value);
  final String value;

  static SpotType fromString(String s) =>
      values.firstWhere((e) => e.value == s);
}

enum AreaType {
  country('country'),
  city('city'),
  neighborhood('neighborhood');

  const AreaType(this.value);
  final String value;

  static AreaType fromString(String s) =>
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
