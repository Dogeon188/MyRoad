import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/tables.dart';

class ZoneDao {
  final AppDatabase _db;

  ZoneDao(this._db);

  Stream<List<Zone>> watchByRoi(String roiId) {
    return (_db.select(_db.zones)
          ..where((t) => t.roiId.equals(roiId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .watch();
  }

  Stream<List<Zone>> watchByTrip(String tripId) {
    return (_db.select(_db.zones)
          ..where((t) => t.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .watch();
  }

  Future<String> insertZone(String name, {String? roiId, String? tripId}) async {
    assert((roiId != null) ^ (tripId != null));
    final count = await (_db.select(_db.zones)
          ..where((t) => roiId != null
              ? t.roiId.equals(roiId)
              : t.tripId.equals(tripId!)))
        .get()
        .then((r) => r.length);

    final entry = ZonesCompanion.insert(
      name: name,
      roiId: Value(roiId),
      tripId: Value(tripId),
      order: Value(count),
    );
    final zone = await _db.into(_db.zones).insertReturning(entry);
    return zone.id;
  }

  Future<void> updateZone(String id, {String? name}) {
    return (_db.update(_db.zones)..where((t) => t.id.equals(id))).write(
      ZonesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteZone(String id) async {
    final regions = await (_db.select(_db.regions)
          ..where((t) => t.zoneId.equals(id)))
        .get();

    for (final region in regions) {
      await _deleteRegionCascade(region.id);
    }
    await (_db.delete(_db.zones)..where((t) => t.id.equals(id))).go();
  }

  Future<void> reorder(List<String> ids) async {
    await _db.batch((batch) {
      for (var i = 0; i < ids.length; i++) {
        batch.update(
          _db.zones,
          ZonesCompanion(order: Value(i)),
          where: ($ZonesTable t) => t.id.equals(ids[i]),
        );
      }
    });
  }

  Future<void> _deleteRegionCascade(String regionId) async {
    final spots = await (_db.select(_db.spots)
          ..where((t) => t.regionId.equals(regionId)))
        .get();

    for (final spot in spots) {
      await (_db.delete(_db.spotCustomInfos)..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(_db.spotOpeningHoursEntries)..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(_db.spotPhotos)..where((t) => t.spotId.equals(spot.id))).go();
    }
    await (_db.delete(_db.spots)..where((t) => t.regionId.equals(regionId))).go();
    await (_db.delete(_db.regions)..where((t) => t.id.equals(regionId))).go();
  }
}
