import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/spot_dao.dart';

class AreaDao {
  final AppDatabase _db;

  AreaDao(this._db);

  Future<Area?> getById(String id) {
    return (_db.select(_db.areas)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Stream<List<Area>> watchByRegion(String regionId) {
    return (_db.select(_db.areas)
          ..where((t) => t.regionId.equals(regionId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .watch();
  }

  Future<String> insertArea(String name, String type, {required String regionId}) async {
    final count = await (_db.select(_db.areas)
          ..where((t) => t.regionId.equals(regionId)))
        .get()
        .then((r) => r.length);

    final entry = AreasCompanion.insert(
      name: name,
      regionId: regionId,
      type: Value(type),
      order: Value(count),
    );
    final area = await _db.into(_db.areas).insertReturning(entry);
    return area.id;
  }

  Future<void> updateArea(String id, {String? name, String? type, int? estimatedDurationMinutes, String? review}) {
    return (_db.update(_db.areas)..where((t) => t.id.equals(id))).write(
      AreasCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        type: type != null ? Value(type) : const Value.absent(),
        estimatedDurationMinutes: estimatedDurationMinutes != null
            ? Value(estimatedDurationMinutes)
            : const Value.absent(),
        review: review != null ? Value(review) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteArea(String id) async {
    final spots = await (_db.select(_db.spots)
          ..where((t) => t.areaId.equals(id)))
        .get();

    for (final spot in spots) {
      await (_db.delete(_db.spotCustomInfos)..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(_db.spotOpeningHoursEntries)..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(_db.spotPhotos)..where((t) => t.spotId.equals(spot.id))).go();
    }
    await (_db.delete(_db.spots)..where((t) => t.areaId.equals(id))).go();
    await (_db.delete(_db.areas)..where((t) => t.id.equals(id))).go();
  }

  Future<void> moveToRegion(String areaId, String newRegionId) async {
    final count = await (_db.select(_db.areas)
          ..where((t) => t.regionId.equals(newRegionId)))
        .get()
        .then((r) => r.length);
    await (_db.update(_db.areas)..where((t) => t.id.equals(areaId)))
        .write(AreasCompanion(regionId: Value(newRegionId), order: Value(count)));
  }

  Future<void> copyToRegion(String areaId, String newRegionId, SpotDao spotDao) async {
    final area = await getById(areaId);
    if (area == null) return;
    final newAreaId = await insertArea(area.name, area.type, regionId: newRegionId);
    await updateArea(newAreaId, estimatedDurationMinutes: area.estimatedDurationMinutes);
    final spots = await spotDao.watchByArea(areaId).first;
    for (final spot in spots) {
      await spotDao.copyToArea(spot.id, newAreaId);
    }
  }

  Future<void> reorder(List<String> ids) async {
    await _db.batch((batch) {
      for (var i = 0; i < ids.length; i++) {
        batch.update(
          _db.areas,
          AreasCompanion(order: Value(i)),
          where: ($AreasTable t) => t.id.equals(ids[i]),
        );
      }
    });
  }
}
