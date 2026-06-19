import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';

class RegionDao {
  final AppDatabase _db;

  RegionDao(this._db);

  Stream<List<Region>> watchAll() {
    return (_db.select(_db.regions)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Region?> getById(String id) {
    return (_db.select(_db.regions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String> insertRegion(String name, String? description) async {
    final entry = RegionsCompanion.insert(
      name: name,
      description: Value(description),
    );
    final region = await _db.into(_db.regions).insertReturning(entry);
    return region.id;
  }

  Future<void> updateRegion(String id, {String? name, String? description}) {
    return (_db.update(_db.regions)..where((t) => t.id.equals(id))).write(
      RegionsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        description: description != null ? Value(description) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteRegion(String id) async {
    final zones = await (_db.select(_db.zones)
          ..where((t) => t.regionId.equals(id)))
        .get();

    for (final zone in zones) {
      await _deleteSpotsByZone(zone.id);
      await (_db.delete(_db.zones)..where((t) => t.id.equals(zone.id))).go();
    }

    await (_db.delete(_db.tripRegions)..where((t) => t.regionId.equals(id))).go();
    await (_db.delete(_db.regions)..where((t) => t.id.equals(id))).go();
  }

  // --- Trip-region references ---

  Stream<List<Region>> watchByTrip(String tripId) {
    final query = _db.select(_db.regions).join([
      innerJoin(_db.tripRegions, _db.tripRegions.regionId.equalsExp(_db.regions.id)),
    ])
      ..where(_db.tripRegions.tripId.equals(tripId))
      ..orderBy([OrderingTerm.asc(_db.tripRegions.order)]);

    return query.watch().map((rows) =>
        rows.map((row) => row.readTable(_db.regions)).toList());
  }

  Future<void> addToTrip(String regionId, String tripId) async {
    final count = await (_db.select(_db.tripRegions)
          ..where((t) => t.tripId.equals(tripId)))
        .get()
        .then((r) => r.length);

    await _db.into(_db.tripRegions).insert(
      TripRegionsCompanion.insert(
        tripId: tripId,
        regionId: regionId,
        order: Value(count),
      ),
    );
  }

  Future<void> removeFromTrip(String regionId, String tripId) {
    return (_db.delete(_db.tripRegions)
          ..where((t) => t.tripId.equals(tripId) & t.regionId.equals(regionId)))
        .go();
  }

  Future<void> reorderInTrip(String tripId, List<String> regionIds) async {
    await _db.batch((batch) {
      for (var i = 0; i < regionIds.length; i++) {
        batch.update(
          _db.tripRegions,
          TripRegionsCompanion(order: Value(i)),
          where: ($TripRegionsTable t) =>
              t.tripId.equals(tripId) & t.regionId.equals(regionIds[i]),
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
