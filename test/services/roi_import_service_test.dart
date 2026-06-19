import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/roi_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/dao/zone_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/services/roi_import_service.dart';

void main() {
  late AppDatabase db;
  late RoiImportService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = RoiImportService(db);
  });

  tearDown(() async => await db.close());

  test('importIntoTrip deep-copies ROI data with new IDs', () async {
    final roiDao = RoiDao(db);
    final regionDao = RegionDao(db);
    final zoneDao = ZoneDao(db);
    final spotDao = SpotDao(db);
    final tripDao = TripDao(db);

    // Create ROI → region → zone → spot + custom info
    final roiId = await roiDao.insertRoi('Japan', null);
    final regionId = await regionDao.insertRegion('Tokyo Area', roiId: roiId);
    final zoneId = await zoneDao.insertZone('Shinjuku', 'neighborhood', regionId: regionId);
    final spotId = await spotDao.insertSpot(
      name: 'Golden Gai', zoneId: zoneId, type: 'spot', lat: 35.6938, lng: 139.7035,
    );
    await spotDao.addCustomInfo(spotId, 'Vibe', 'Amazing');

    // Create trip and import
    final tripId = await tripDao.insertTrip(name: 'Japan 2026');
    await service.importIntoTrip(roiId: roiId, tripId: tripId);

    // Verify trip has copied regions
    final tripRegions = await regionDao.watchByTrip(tripId).first;
    expect(tripRegions.length, 1);
    expect(tripRegions[0].name, 'Tokyo Area');
    expect(tripRegions[0].tripId, tripId);
    expect(tripRegions[0].roiId, isNull);
    expect(tripRegions[0].id, isNot(regionId));

    // Verify zones were copied under the new region
    final tripZones = await zoneDao.watchByRegion(tripRegions[0].id).first;
    expect(tripZones.length, 1);
    expect(tripZones[0].name, 'Shinjuku');
    expect(tripZones[0].id, isNot(zoneId));

    // Verify spots were copied
    final tripSpots = await spotDao.watchByZone(tripZones[0].id).first;
    expect(tripSpots.length, 1);
    expect(tripSpots[0].name, 'Golden Gai');
    expect(tripSpots[0].id, isNot(spotId));

    // Verify custom info was copied
    final infos = await spotDao.getCustomInfos(tripSpots[0].id);
    expect(infos.length, 1);
    expect(infos[0].label, 'Vibe');
    expect(infos[0].value, 'Amazing');

    // Verify TripRoiSource was recorded
    final sources = await (db.select(db.tripRoiSources)..where((t) => t.tripId.equals(tripId))).get();
    expect(sources.length, 1);
    expect(sources[0].roiId, roiId);
  });
}
