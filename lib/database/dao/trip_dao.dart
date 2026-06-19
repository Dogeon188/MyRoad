import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';

class TripDao {
  final AppDatabase _db;

  TripDao(this._db);

  Stream<List<Trip>> watchAll() {
    return (_db.select(_db.trips)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Trip?> getById(String id) {
    return (_db.select(_db.trips)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String> insertTrip({
    required String name,
    String transportPreference = 'walk',
    String planMode = 'coarse',
    DateTime? startDate,
    DateTime? endDate,
    int bufferTimeDefaultMinutes = 15,
  }) async {
    final entry = TripsCompanion.insert(
      name: name,
      transportPreference: Value(transportPreference),
      planMode: Value(planMode),
      startDate: Value(startDate),
      endDate: Value(endDate),
      bufferTimeDefaultMinutes: Value(bufferTimeDefaultMinutes),
    );
    final trip = await _db.into(_db.trips).insertReturning(entry);
    return trip.id;
  }

  Future<void> updateTrip(String id, {
    String? name,
    String? transportPreference,
    String? planMode,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(
      TripsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        transportPreference: transportPreference != null ? Value(transportPreference) : const Value.absent(),
        planMode: planMode != null ? Value(planMode) : const Value.absent(),
        startDate: startDate != null ? Value(startDate) : const Value.absent(),
        endDate: endDate != null ? Value(endDate) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteTrip(String id) async {
    // Itinerary
    final days = await (_db.select(_db.itineraryDays)..where((t) => t.tripId.equals(id))).get();
    for (final day in days) {
      await (_db.delete(_db.dayItems)..where((t) => t.dayId.equals(day.id))).go();
    }
    await (_db.delete(_db.itineraryDays)..where((t) => t.tripId.equals(id))).go();
    await (_db.delete(_db.hotelStays)..where((t) => t.tripId.equals(id))).go();
    await (_db.delete(_db.transports)..where((t) => t.tripId.equals(id))).go();
    await (_db.delete(_db.albumEntries)..where((t) => t.tripId.equals(id))).go();
    await (_db.delete(_db.tripRoiSources)..where((t) => t.tripId.equals(id))).go();

    // Trip-owned regions → zones → spots
    final regions = await (_db.select(_db.regions)..where((t) => t.tripId.equals(id))).get();
    for (final region in regions) {
      final zones = await (_db.select(_db.zones)..where((t) => t.regionId.equals(region.id))).get();
      for (final zone in zones) {
        await _deleteSpotsByZone(zone.id);
        await (_db.delete(_db.zones)..where((t) => t.id.equals(zone.id))).go();
      }
      await (_db.delete(_db.regions)..where((t) => t.id.equals(region.id))).go();
    }

    await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _deleteSpotsByZone(String zoneId) async {
    final spots = await (_db.select(_db.spots)..where((t) => t.zoneId.equals(zoneId))).get();
    for (final spot in spots) {
      await (_db.delete(_db.spotCustomInfos)..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(_db.spotOpeningHoursEntries)..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(_db.spotPhotos)..where((t) => t.spotId.equals(spot.id))).go();
    }
    await (_db.delete(_db.spots)..where((t) => t.zoneId.equals(zoneId))).go();
  }
}
