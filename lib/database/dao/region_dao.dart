import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';

// Region = big grouping (can span days). Belongs to ROI or Trip.
class RegionDao {
  final AppDatabase _db;

  RegionDao(this._db);

  Stream<List<Region>> watchByRoi(String roiId) {
    return (_db.select(_db.regions)
          ..where((t) => t.roiId.equals(roiId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .watch();
  }

  Stream<List<Region>> watchByTrip(String tripId) {
    return (_db.select(_db.regions)
          ..where((t) => t.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .watch();
  }

  Future<String> insertRegion(String name, {String? roiId, String? tripId}) async {
    assert(roiId != null || tripId != null);
    final query = _db.select(_db.regions);
    if (roiId != null) {
      query.where((t) => t.roiId.equals(roiId));
    } else {
      query.where((t) => t.tripId.equals(tripId!));
    }
    final count = await query.get().then((r) => r.length);

    final entry = RegionsCompanion.insert(
      name: name,
      roiId: Value(roiId),
      tripId: Value(tripId),
      order: Value(count),
    );
    final region = await _db.into(_db.regions).insertReturning(entry);
    return region.id;
  }

  Future<void> updateRegion(String id, {String? name}) {
    return (_db.update(_db.regions)..where((t) => t.id.equals(id))).write(
      RegionsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteRegion(String id) async {
    // Delete zones under this region (and their spots)
    final zones = await (_db.select(_db.zones)
          ..where((t) => t.regionId.equals(id)))
        .get();

    for (final zone in zones) {
      await _deleteSpotsByZone(zone.id);
      await (_db.delete(_db.zones)..where((t) => t.id.equals(zone.id))).go();
    }
    await (_db.delete(_db.regions)..where((t) => t.id.equals(id))).go();
  }

  Future<void> reorder(List<String> ids) async {
    await _db.batch((batch) {
      for (var i = 0; i < ids.length; i++) {
        batch.update(
          _db.regions,
          RegionsCompanion(order: Value(i)),
          where: ($RegionsTable t) => t.id.equals(ids[i]),
        );
      }
    });
  }

  Future<void> _deleteSpotsByZone(String zoneId) async {
    final spots = await (_db.select(_db.spots)
          ..where((t) => t.zoneId.equals(zoneId)))
        .get();

    for (final spot in spots) {
      await (_db.delete(_db.spotCustomInfos)..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(_db.spotOpeningHoursEntries)..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(_db.spotPhotos)..where((t) => t.spotId.equals(spot.id))).go();
    }
    await (_db.delete(_db.spots)..where((t) => t.zoneId.equals(zoneId))).go();
  }
}
