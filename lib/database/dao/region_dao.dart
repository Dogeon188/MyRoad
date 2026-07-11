import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';

class RegionDao {
  final AppDatabase _db;

  RegionDao(this._db);

  Stream<List<Region>> watchAll() {
    return (_db.select(_db.regions)
          ..where((t) => t.sourceRegionId.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Region?> getById(String id) {
    return (_db.select(
      _db.regions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<String> insertRegion(
    String name,
    String? description, {
    int? iconCode,
  }) async {
    final entry = RegionsCompanion.insert(
      name: name,
      description: Value(description),
      iconCode: Value(iconCode),
    );
    final region = await _db.into(_db.regions).insertReturning(entry);
    return region.id;
  }

  Future<void> updateRegion(
    String id, {
    String? name,
    String? description,
    String? review,
    Value<int?> rating = const Value.absent(),
    String? currency,
    Value<int?> iconCode = const Value.absent(),
  }) {
    return (_db.update(_db.regions)..where((t) => t.id.equals(id))).write(
      RegionsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        description: description != null
            ? Value(description)
            : const Value.absent(),
        review: review != null ? Value(review) : const Value.absent(),
        rating: rating,
        currency: currency != null ? Value(currency) : const Value.absent(),
        iconCode: iconCode,
      ),
    );
  }

  Future<void> deleteRegion(String id) async {
    final areas = await (_db.select(
      _db.areas,
    )..where((t) => t.regionId.equals(id))).get();

    for (final area in areas) {
      await _deleteSpotsByArea(area.id);
      await (_db.delete(_db.areas)..where((t) => t.id.equals(area.id))).go();
    }

    await (_db.delete(
      _db.tripRegions,
    )..where((t) => t.regionId.equals(id))).go();
    await (_db.delete(_db.regions)..where((t) => t.id.equals(id))).go();
  }

  Stream<Map<String, ({int areas, int spots})>> watchRegionStats() {
    final areaCount = _db.areas.id.count(distinct: true);
    final spotCount = _db.spots.id.count(distinct: true);

    final query =
        _db.select(_db.regions).join([
            leftOuterJoin(
              _db.areas,
              _db.areas.regionId.equalsExp(_db.regions.id),
            ),
            leftOuterJoin(_db.spots, _db.spots.areaId.equalsExp(_db.areas.id)),
          ])
          ..groupBy([_db.regions.id])
          ..addColumns([areaCount, spotCount]);

    return query.watch().map((rows) {
      final map = <String, ({int areas, int spots})>{};
      for (final row in rows) {
        final region = row.readTable(_db.regions);
        map[region.id] = (
          areas: row.read(areaCount) ?? 0,
          spots: row.read(spotCount) ?? 0,
        );
      }
      return map;
    });
  }

  // --- Trip-region references ---

  Stream<List<Region>> watchByTrip(String tripId) {
    final query =
        _db.select(_db.regions).join([
            innerJoin(
              _db.tripRegions,
              _db.tripRegions.regionId.equalsExp(_db.regions.id),
            ),
          ])
          ..where(_db.tripRegions.tripId.equals(tripId))
          ..orderBy([OrderingTerm.asc(_db.tripRegions.order)]);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(_db.regions)).toList(),
    );
  }

  Future<void> addToTrip(String regionId, String tripId) async {
    final count = await (_db.select(
      _db.tripRegions,
    )..where((t) => t.tripId.equals(tripId))).get().then((r) => r.length);

    await _db
        .into(_db.tripRegions)
        .insert(
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

  Future<String> deepCopyForTrip(
    String regionId,
    String tripId,
    AreaDao areaDao,
    SpotDao spotDao,
  ) async {
    final region = await getById(regionId);
    if (region == null) throw StateError('Region $regionId not found');

    final newRegionId = await insertRegion(region.name, region.description);
    await updateRegion(
      newRegionId,
      review: region.review,
      rating: region.rating != null
          ? Value(region.rating)
          : const Value.absent(),
      currency: region.currency,
      iconCode: Value(region.iconCode),
    );
    await (_db.update(_db.regions)..where((t) => t.id.equals(newRegionId)))
        .write(RegionsCompanion(sourceRegionId: Value(regionId)));

    final areas = await areaDao.watchByRegion(regionId).first;
    for (final area in areas) {
      await areaDao.copyToRegion(area.id, newRegionId, spotDao);
    }

    await addToTrip(newRegionId, tripId);
    return newRegionId;
  }

  Future<void> _deleteSpotsByArea(String areaId) async {
    final spots = await (_db.select(
      _db.spots,
    )..where((t) => t.areaId.equals(areaId))).get();

    for (final spot in spots) {
      await (_db.delete(
        _db.spotOpeningHoursEntries,
      )..where((t) => t.spotId.equals(spot.id))).go();
      await (_db.delete(
        _db.spotPhotos,
      )..where((t) => t.spotId.equals(spot.id))).go();
    }
    await (_db.delete(_db.spots)..where((t) => t.areaId.equals(areaId))).go();
  }
}
