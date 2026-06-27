import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/api/directions_api_client.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/services/transport_service.dart';

final regionDaoProvider = Provider<RegionDao>((ref) {
  return RegionDao(ref.watch(appDatabaseProvider));
});

final areaDaoProvider = Provider<AreaDao>((ref) {
  return AreaDao(ref.watch(appDatabaseProvider));
});

final spotDaoProvider = Provider<SpotDao>((ref) {
  return SpotDao(ref.watch(appDatabaseProvider));
});

final tripDaoProvider = Provider<TripDao>((ref) {
  return TripDao(ref.watch(appDatabaseProvider));
});

final itineraryDaoProvider = Provider<ItineraryDao>((ref) {
  return ItineraryDao(ref.watch(appDatabaseProvider));
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

// Trip-scoped stream providers — eliminates nested StreamBuilders
final tripProvider = StreamProvider.family<Trip?, String>((ref, tripId) {
  return ref.watch(tripDaoProvider).watchById(tripId);
});

final itineraryDaysProvider =
    StreamProvider.family<List<ItineraryDay>, String>((ref, tripId) {
  return ref.watch(itineraryDaoProvider).watchDays(tripId);
});

final hotelStaysProvider =
    StreamProvider.family<List<HotelStay>, String>((ref, tripId) {
  return ref.watch(itineraryDaoProvider).watchHotelStays(tripId);
});

final spotTimesProvider =
    StreamProvider.family<Map<String, int>, String>((ref, tripId) {
  return ref.watch(itineraryDaoProvider).watchSpotTimes(tripId);
});

final skippedSpotsProvider =
    StreamProvider.family<Set<String>, String>((ref, tripId) {
  return ref.watch(itineraryDaoProvider).watchSkippedSpots(tripId);
});

final afterTransportSpotsProvider =
    StreamProvider.family<Set<String>, String>((ref, tripId) {
  return ref.watch(itineraryDaoProvider).watchAfterTransportSpots(tripId);
});

final travelPassesProvider =
    StreamProvider.family<List<TravelPassesData>, String>((ref, tripId) {
  return ref.watch(itineraryDaoProvider).watchPasses(tripId);
});

final tripRegionsProvider =
    StreamProvider.family<List<Region>, String>((ref, tripId) {
  return ref.watch(regionDaoProvider).watchByTrip(tripId);
});

final dayItemsProvider =
    StreamProvider.family<List<DayItem>, String>((ref, dayId) {
  return ref.watch(itineraryDaoProvider).watchDayItems(dayId);
});
