import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/api/directions_api_client.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/zone_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/services/transport_service.dart';

final regionDaoProvider = Provider<RegionDao>((ref) {
  return RegionDao(ref.watch(appDatabaseProvider));
});

final zoneDaoProvider = Provider<ZoneDao>((ref) {
  return ZoneDao(ref.watch(appDatabaseProvider));
});

final spotDaoProvider = Provider<SpotDao>((ref) {
  return SpotDao(ref.watch(appDatabaseProvider));
});

final tripDaoProvider = Provider<TripDao>((ref) {
  return TripDao(ref.watch(appDatabaseProvider));
});

final directionsApiClientProvider = Provider<DirectionsApiClient>((ref) {
  return DirectionsApiClient();
});

final transportServiceProvider = Provider<TransportService>((ref) {
  return TransportService(
    ref.watch(appDatabaseProvider),
    ref.watch(directionsApiClientProvider),
  );
});
