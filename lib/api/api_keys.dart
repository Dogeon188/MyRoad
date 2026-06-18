import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  static String get placesApiKey => dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
}
