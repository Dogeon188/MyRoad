import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/tables.dart';

class RegionDao {
  final AppDatabase _db;

  RegionDao(this._db);

  Stream<List<Region>> watchByZone(String zoneId) {
    return (_db.select(_db.regions)
          ..where((t) => t.zoneId.equals(zoneId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .watch();
  }

  Future<String> insertRegion(String name, String zoneId, String type) async {
    final count = await (_db.select(_db.regions)
          ..where((t) => t.zoneId.equals(zoneId)))
        .get()
        .then((r) => r.length);

    final entry = RegionsCompanion.insert(
      name: name,
      zoneId: zoneId,
      type: Value(type),
      order: Value(count),
    );
    final region = await _db.into(_db.regions).insertReturning(entry);
    return region.id;
  }

  Future<void> updateRegion(
    String id, {
    String? name,
    String? type,
    int? estimatedDurationMinutes,
    double? boundsSouth,
    double? boundsWest,
    double? boundsNorth,
    double? boundsEast,
  }) {
    return (_db.update(_db.regions)..where((t) => t.id.equals(id))).write(
      RegionsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        type: type != null ? Value(type) : const Value.absent(),
        estimatedDurationMinutes: estimatedDurationMinutes != null
            ? Value(estimatedDurationMinutes)
            : const Value.absent(),
        boundsSouth: boundsSouth != null ? Value(boundsSouth) : const Value.absent(),
        boundsWest: boundsWest != null ? Value(boundsWest) : const Value.absent(),
        boundsNorth: boundsNorth != null ? Value(boundsNorth) : const Value.absent(),
        boundsEast: boundsEast != null ? Value(boundsEast) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteRegion(String id) async {
    final spots = await (_db.select(_db.spots)
          ..where((t) => t.regionId.equals(id)))
        .get();

    for (final spot in spots) {
      await (_db.delete(_db.spotCustomInfos)..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(_db.spotOpeningHoursEntries)..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(_db.spotPhotos)..where((t) => t.spotId.equals(spot.id))).go();
    }
    await (_db.delete(_db.spots)..where((t) => t.regionId.equals(id))).go();
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
}
