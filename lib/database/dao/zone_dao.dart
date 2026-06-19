import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';

class ZoneDao {
  final AppDatabase _db;

  ZoneDao(this._db);

  Stream<List<Zone>> watchByRegion(String regionId) {
    return (_db.select(_db.zones)
          ..where((t) => t.regionId.equals(regionId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .watch();
  }

  Future<String> insertZone(String name, String type, {required String regionId}) async {
    final count = await (_db.select(_db.zones)
          ..where((t) => t.regionId.equals(regionId)))
        .get()
        .then((r) => r.length);

    final entry = ZonesCompanion.insert(
      name: name,
      regionId: regionId,
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
