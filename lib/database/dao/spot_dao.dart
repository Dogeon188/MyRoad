import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';

class SpotDao {
  final AppDatabase _db;

  SpotDao(this._db);

  Stream<List<Spot>> watchByArea(String areaId) {
    return (_db.select(_db.spots)
          ..where((t) => t.areaId.equals(areaId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .watch();
  }

  Future<Spot?> getById(String id) {
    return (_db.select(_db.spots)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String> insertSpot({
    required String name,
    required String areaId,
    required String type,
    double? lat,
    double? lng,
    String? address,
    String? googlePlaceId,
    String? previewImageUrl,
  }) async {
    final entry = SpotsCompanion.insert(
      name: name,
      areaId: areaId,
      type: Value(type),
      lat: Value(lat),
      lng: Value(lng),
      address: address != null ? Value(address) : const Value.absent(),
      googlePlaceId: Value(googlePlaceId),
      previewImageUrl: Value(previewImageUrl),
    );
    final spot = await _db.into(_db.spots).insertReturning(entry);
    return spot.id;
  }

  Future<void> updateSpot(
    String id, {
    String? name,
    String? type,
    String? notes,
    int? estimatedVisitDurationMinutes,
    int? bufferTimeMinutes,
    String? review,
    String? previewImageUrl,
    Value<int?> rating = const Value.absent(),
    Value<String?> price = const Value.absent(),
  }) {
    return (_db.update(_db.spots)..where((t) => t.id.equals(id))).write(
      SpotsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        type: type != null ? Value(type) : const Value.absent(),
        notes: notes != null ? Value(notes) : const Value.absent(),
        estimatedVisitDurationMinutes: estimatedVisitDurationMinutes != null
            ? Value(estimatedVisitDurationMinutes)
            : const Value.absent(),
        bufferTimeMinutes: bufferTimeMinutes != null
            ? Value(bufferTimeMinutes)
            : const Value.absent(),
        review: review != null ? Value(review) : const Value.absent(),
        previewImageUrl: previewImageUrl != null ? Value(previewImageUrl) : const Value.absent(),
        rating: rating,
        price: price,
      ),
    );
  }

  Future<void> deleteSpot(String id) async {
    await (_db.delete(_db.spotCustomInfos)..where((t) => t.spotId.equals(id))).go();
    await (_db.delete(_db.spotOpeningHoursEntries)..where((t) => t.spotId.equals(id))).go();
    await (_db.delete(_db.spotPhotos)..where((t) => t.spotId.equals(id))).go();
    await (_db.delete(_db.spots)..where((t) => t.id.equals(id))).go();
  }

  Future<void> reorder(List<String> ids) async {
    // Read old order before updating
    final first = await (_db.select(_db.spots)..where((t) => t.id.equals(ids.first))).getSingle();
    final oldSpots = await (_db.select(_db.spots)
          ..where((t) => t.areaId.equals(first.areaId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .get();
    final oldIds = oldSpots.map((s) => s.id).toList();

    await _db.batch((batch) {
      for (var i = 0; i < ids.length; i++) {
        batch.update(
          _db.spots,
          SpotsCompanion(order: Value(i)),
          where: ($SpotsTable t) => t.id.equals(ids[i]),
        );
      }
    });

    // Only invalidate transports for adjacent pairs that changed
    final oldPairs = <(String, String)>{};
    for (var i = 0; i < oldIds.length - 1; i++) {
      oldPairs.add((oldIds[i], oldIds[i + 1]));
    }
    final newPairs = <(String, String)>{};
    for (var i = 0; i < ids.length - 1; i++) {
      newPairs.add((ids[i], ids[i + 1]));
    }
    final broken = oldPairs.difference(newPairs);
    for (final (from, to) in broken) {
      await (_db.delete(_db.transports)
            ..where((t) => t.fromSpotId.equals(from) & t.toSpotId.equals(to)))
          .go();
    }
  }

  Future<void> addCustomInfo(String spotId, String label, String value) async {
    await _db.into(_db.spotCustomInfos).insert(
      SpotCustomInfosCompanion.insert(spotId: spotId, label: label, value: value),
    );
  }

  Future<List<SpotCustomInfo>> getCustomInfos(String spotId) {
    return (_db.select(_db.spotCustomInfos)..where((t) => t.spotId.equals(spotId))).get();
  }

  Future<void> deleteCustomInfo(String id) {
    return (_db.delete(_db.spotCustomInfos)..where((t) => t.id.equals(id))).go();
  }

  Future<void> addOpeningHours(String spotId,
      {required int day, required int openMinutes, required int closeMinutes}) async {
    await _db.into(_db.spotOpeningHoursEntries).insert(
      SpotOpeningHoursEntriesCompanion.insert(
        spotId: spotId,
        day: day,
        openMinutes: openMinutes,
        closeMinutes: closeMinutes,
      ),
    );
  }

  Future<List<SpotOpeningHoursEntry>> getOpeningHours(String spotId) {
    return (_db.select(_db.spotOpeningHoursEntries)
          ..where((t) => t.spotId.equals(spotId))
          ..orderBy([(t) => OrderingTerm.asc(t.day)]))
        .get();
  }

  Future<void> addPhoto(String spotId, String uri, {String? caption, double? lat, double? lng}) async {
    await _db.into(_db.spotPhotos).insert(
      SpotPhotosCompanion.insert(
        spotId: spotId,
        uri: uri,
        caption: Value(caption),
        lat: Value(lat),
        lng: Value(lng),
      ),
    );
  }

  Future<List<SpotPhoto>> getPhotos(String spotId) {
    return (_db.select(_db.spotPhotos)..where((t) => t.spotId.equals(spotId))).get();
  }

  Future<void> deletePhoto(String id) {
    return (_db.delete(_db.spotPhotos)..where((t) => t.id.equals(id))).go();
  }

  Future<void> moveToArea(String spotId, String newAreaId) {
    return (_db.update(_db.spots)..where((t) => t.id.equals(spotId)))
        .write(SpotsCompanion(areaId: Value(newAreaId)));
  }

  Future<void> copyToArea(String spotId, String newAreaId) async {
    final spot = await getById(spotId);
    if (spot == null) return;
    final newId = await insertSpot(
      name: spot.name,
      areaId: newAreaId,
      type: spot.type,
      lat: spot.lat,
      lng: spot.lng,
      address: spot.address.isEmpty ? null : spot.address,
      googlePlaceId: spot.googlePlaceId,
      previewImageUrl: spot.previewImageUrl,
    );
    await updateSpot(newId,
      notes: spot.notes.isEmpty ? null : spot.notes,
      estimatedVisitDurationMinutes: spot.estimatedVisitDurationMinutes,
      bufferTimeMinutes: spot.bufferTimeMinutes,
      review: spot.review,
    );
    // Copy custom infos
    final infos = await getCustomInfos(spotId);
    for (final info in infos) {
      await addCustomInfo(newId, info.label, info.value);
    }
    // Copy opening hours
    final hours = await getOpeningHours(spotId);
    for (final h in hours) {
      await addOpeningHours(newId, day: h.day, openMinutes: h.openMinutes, closeMinutes: h.closeMinutes);
    }
  }
}
