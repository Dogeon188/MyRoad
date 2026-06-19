import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';
import 'package:uuid/uuid.dart';

class RoiImportService {
  final AppDatabase _db;
  static const _uuid = Uuid();

  RoiImportService(this._db);

  Future<void> importIntoTrip({required String roiId, required String tripId}) async {
    await _db.into(_db.tripRoiSources).insert(
      TripRoiSourcesCompanion.insert(tripId: tripId, roiId: roiId),
    );

    // ROI → Regions (big) → Zones (small) → Spots
    final regions = await (_db.select(_db.regions)
          ..where((t) => t.roiId.equals(roiId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .get();

    for (final region in regions) {
      final newRegionId = _uuid.v4();
      await _db.into(_db.regions).insert(RegionsCompanion.insert(
        id: Value(newRegionId),
        name: region.name,
        tripId: Value(tripId),
        order: Value(region.order),
      ));

      final zones = await (_db.select(_db.zones)
            ..where((t) => t.regionId.equals(region.id))
            ..orderBy([(t) => OrderingTerm.asc(t.order)]))
          .get();

      for (final zone in zones) {
        final newZoneId = _uuid.v4();
        await _db.into(_db.zones).insert(ZonesCompanion.insert(
          id: Value(newZoneId),
          name: zone.name,
          regionId: Value(newRegionId),
          type: Value(zone.type),
          order: Value(zone.order),
          boundsSouth: Value(zone.boundsSouth),
          boundsWest: Value(zone.boundsWest),
          boundsNorth: Value(zone.boundsNorth),
          boundsEast: Value(zone.boundsEast),
          estimatedDurationMinutes: Value(zone.estimatedDurationMinutes),
        ));

        await _copySpots(zone.id, newZoneId);
      }
    }

    // Also copy direct ROI zones (not under any region)
    final directZones = await (_db.select(_db.zones)
          ..where((t) => t.roiId.equals(roiId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .get();

    for (final zone in directZones) {
      final newZoneId = _uuid.v4();
      // ponytail: direct zones get a synthetic region, or just copy as-is without region
      // For now, skip regionId — these are orphan zones in the trip context
      await _db.into(_db.zones).insert(ZonesCompanion.insert(
        id: Value(newZoneId),
        name: zone.name,
        order: Value(zone.order),
        type: Value(zone.type),
        boundsSouth: Value(zone.boundsSouth),
        boundsWest: Value(zone.boundsWest),
        boundsNorth: Value(zone.boundsNorth),
        boundsEast: Value(zone.boundsEast),
        estimatedDurationMinutes: Value(zone.estimatedDurationMinutes),
      ));

      await _copySpots(zone.id, newZoneId);
    }
  }

  Future<void> _copySpots(String fromZoneId, String toZoneId) async {
    final spots = await (_db.select(_db.spots)..where((t) => t.zoneId.equals(fromZoneId))).get();

    for (final spot in spots) {
      final newSpotId = _uuid.v4();
      await _db.into(_db.spots).insert(SpotsCompanion.insert(
        id: Value(newSpotId),
        zoneId: toZoneId,
        name: spot.name,
        type: Value(spot.type),
        lat: spot.lat,
        lng: spot.lng,
        address: Value(spot.address),
        googlePlaceId: Value(spot.googlePlaceId),
        previewImageUrl: Value(spot.previewImageUrl),
        order: Value(spot.order),
        notes: Value(spot.notes),
        estimatedVisitDurationMinutes: Value(spot.estimatedVisitDurationMinutes),
        bufferTimeMinutes: Value(spot.bufferTimeMinutes),
      ));

      // Custom info
      final infos = await (_db.select(_db.spotCustomInfos)..where((t) => t.spotId.equals(spot.id))).get();
      for (final info in infos) {
        await _db.into(_db.spotCustomInfos).insert(
          SpotCustomInfosCompanion.insert(spotId: newSpotId, label: info.label, value: info.value),
        );
      }

      // Opening hours
      final hours = await (_db.select(_db.spotOpeningHoursEntries)..where((t) => t.spotId.equals(spot.id))).get();
      for (final h in hours) {
        await _db.into(_db.spotOpeningHoursEntries).insert(
          SpotOpeningHoursEntriesCompanion.insert(spotId: newSpotId, day: h.day, openMinutes: h.openMinutes, closeMinutes: h.closeMinutes),
        );
      }

      // Photos — copy references (ponytail: don't duplicate files, just link same URIs)
      final photos = await (_db.select(_db.spotPhotos)..where((t) => t.spotId.equals(spot.id))).get();
      for (final p in photos) {
        await _db.into(_db.spotPhotos).insert(
          SpotPhotosCompanion.insert(
            spotId: newSpotId,
            uri: p.uri,
            caption: Value(p.caption),
            takenAt: Value(p.takenAt),
            lat: Value(p.lat),
            lng: Value(p.lng),
          ),
        );
      }
    }
  }
}
