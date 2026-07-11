import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/region_dao.dart';

class TripDao {
  final AppDatabase _db;

  TripDao(this._db);

  Stream<List<Trip>> watchAll() {
    return (_db.select(
      _db.trips,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  Future<Trip?> getById(String id) {
    return (_db.select(
      _db.trips,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Stream<Trip?> watchById(String id) {
    return (_db.select(
      _db.trips,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
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

  Future<void> updateTrip(
    String id, {
    String? name,
    String? transportPreference,
    String? planMode,
    DateTime? startDate,
    DateTime? endDate,
    Value<int?> iconCode = const Value.absent(),
  }) {
    return (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(
      TripsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        transportPreference: transportPreference != null
            ? Value(transportPreference)
            : const Value.absent(),
        planMode: planMode != null ? Value(planMode) : const Value.absent(),
        startDate: startDate != null ? Value(startDate) : const Value.absent(),
        endDate: endDate != null ? Value(endDate) : const Value.absent(),
        iconCode: iconCode,
      ),
    );
  }

  Future<void> clearTripDates(String id) {
    return (_db.update(_db.trips)..where((t) => t.id.equals(id))).write(
      const TripsCompanion(startDate: Value(null), endDate: Value(null)),
    );
  }

  Stream<Map<String, int>> watchTripRegionCounts() {
    final query = _db.selectOnly(_db.tripRegions)
      ..addColumns([_db.tripRegions.tripId, _db.tripRegions.id.count()])
      ..groupBy([_db.tripRegions.tripId]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.tripRegions.tripId)!: row.read(
            _db.tripRegions.id.count(),
          )!,
      },
    );
  }

  Future<void> deleteTrip(String id) async {
    final days = await (_db.select(
      _db.itineraryDays,
    )..where((t) => t.tripId.equals(id))).get();
    for (final day in days) {
      await (_db.delete(
        _db.dayItems,
      )..where((t) => t.dayId.equals(day.id))).go();
    }
    await (_db.delete(
      _db.itineraryDays,
    )..where((t) => t.tripId.equals(id))).go();
    await (_db.delete(_db.hotelStays)..where((t) => t.tripId.equals(id))).go();
    await (_db.delete(_db.transports)..where((t) => t.tripId.equals(id))).go();
    await (_db.delete(
      _db.albumEntries,
    )..where((t) => t.tripId.equals(id))).go();

    // Delete copied (trip-private) regions before removing junction records
    final tripRegionRows = await (_db.select(
      _db.tripRegions,
    )..where((t) => t.tripId.equals(id))).get();
    final regionDao = RegionDao(_db);
    for (final tr in tripRegionRows) {
      final region = await regionDao.getById(tr.regionId);
      if (region != null && region.sourceRegionId != null) {
        await regionDao.deleteRegion(region.id);
      }
    }

    await (_db.delete(_db.tripRegions)..where((t) => t.tripId.equals(id))).go();
    await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
  }
}
