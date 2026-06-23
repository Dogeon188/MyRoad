enum TransportMode {
  walk('walk'),
  transit('transit'),
  car('car'),
  bicycle('bicycle');

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

const currencySymbols = {
  'JPY': '¥',
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'KRW': '₩',
  'TWD': 'NT\$',
  'CNY': '¥',
  'THB': '฿',
  'HKD': 'HK\$',
  'SGD': 'S\$',
  'AUD': 'A\$',
  'CAD': 'CA\$',
  'CHF': 'CHF',
};

String currencySymbol(String code) => currencySymbols[code] ?? code;

// ponytail: covers common travel destinations only, extend when needed
const countryCurrency = {
  'JP': 'JPY', 'US': 'USD', 'GB': 'GBP', 'KR': 'KRW', 'TW': 'TWD',
  'CN': 'CNY', 'HK': 'HKD', 'SG': 'SGD', 'TH': 'THB', 'AU': 'AUD',
  'CA': 'CAD', 'CH': 'CHF', 'DE': 'EUR', 'FR': 'EUR', 'IT': 'EUR',
  'ES': 'EUR', 'NL': 'EUR', 'AT': 'EUR', 'BE': 'EUR', 'PT': 'EUR',
  'GR': 'EUR', 'IE': 'EUR', 'FI': 'EUR',
};
