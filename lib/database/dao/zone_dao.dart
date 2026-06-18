import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';

// Zone = small area (fits 1 day). Belongs to Region or directly to ROI.
class ZoneDao {
  final AppDatabase _db;

  ZoneDao(this._db);

  Stream<List<Zone>> watchByRoi(String roiId) {
    return (_db.select(_db.zones)
          ..where((t) => t.roiId.equals(roiId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .watch();
  }

  Stream<List<Zone>> watchByRegion(String regionId) {
    return (_db.select(_db.zones)
          ..where((t) => t.regionId.equals(regionId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .watch();
  }

  Future<String> insertZone(String name, String type, {String? roiId, String? regionId}) async {
    final query = _db.select(_db.zones);
    if (roiId != null) {
      query.where((t) => t.roiId.equals(roiId));
    } else if (regionId != null) {
      query.where((t) => t.regionId.equals(regionId));
    }
    final count = await query.get().then((r) => r.length);

    final entry = ZonesCompanion.insert(
      name: name,
      roiId: Value(roiId),
      regionId: Value(regionId),
      type: Value(type),
      order: Value(count),
    );
    final zone = await _db.into(_db.zones).insertReturning(entry);
    return zone.id;
  }

  Future<void> updateZone(String id, {String? name, String? type, int? estimatedDurationMinutes}) {
    return (_db.update(_db.zones)..where((t) => t.id.equals(id))).write(
      ZonesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        type: type != null ? Value(type) : const Value.absent(),
        estimatedDurationMinutes: estimatedDurationMinutes != null
            ? Value(estimatedDurationMinutes)
            : const Value.absent(),
      ),
    );
  }

  Future<void> assignToRegion(String zoneId, String? regionId, {String? roiId}) {
    return (_db.update(_db.zones)..where((t) => t.id.equals(zoneId))).write(
      ZonesCompanion(
        regionId: Value(regionId),
        roiId: roiId != null ? Value(roiId) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteZone(String id) async {
    final spots = await (_db.select(_db.spots)
          ..where((t) => t.zoneId.equals(id)))
        .get();

    for (final spot in spots) {
      await (_db.delete(_db.spotCustomInfos)..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(_db.spotOpeningHoursEntries)..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(_db.spotPhotos)..where((t) => t.spotId.equals(spot.id))).go();
    }
    await (_db.delete(_db.spots)..where((t) => t.zoneId.equals(id))).go();
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
}
