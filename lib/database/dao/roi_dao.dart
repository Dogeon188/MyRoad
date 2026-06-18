import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';

class RoiDao {
  final AppDatabase _db;

  RoiDao(this._db);

  Stream<List<Roi>> watchAll() {
    return (_db.select(_db.rois)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Roi?> getById(String id) {
    return (_db.select(_db.rois)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String> insertRoi(String name, String? description) async {
    final entry = RoisCompanion.insert(
      name: name,
      description: Value(description),
    );
    final roi = await _db.into(_db.rois).insertReturning(entry);
    return roi.id;
  }

  Future<void> updateRoi(String id, {String? name, String? description}) {
    return (_db.update(_db.rois)..where((t) => t.id.equals(id))).write(
      RoisCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteRoi(String id) async {
    // Delete regions (big) and their zones
    final regions = await (_db.select(_db.regions)
          ..where((t) => t.roiId.equals(id)))
        .get();

    for (final region in regions) {
      final zones = await (_db.select(_db.zones)
            ..where((t) => t.regionId.equals(region.id)))
          .get();

      for (final zone in zones) {
        await _deleteSpotsByZone(zone.id);
        await (_db.delete(_db.zones)..where((t) => t.id.equals(zone.id))).go();
      }
      await (_db.delete(_db.regions)..where((t) => t.id.equals(region.id))).go();
    }

    // Delete direct ROI zones (not under a region)
    final directZones = await (_db.select(_db.zones)
          ..where((t) => t.roiId.equals(id)))
        .get();

    for (final zone in directZones) {
      await _deleteSpotsByZone(zone.id);
      await (_db.delete(_db.zones)..where((t) => t.id.equals(zone.id))).go();
    }

    await (_db.delete(_db.rois)..where((t) => t.id.equals(id))).go();
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
