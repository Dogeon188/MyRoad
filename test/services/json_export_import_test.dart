import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/services/json_export_service.dart';
import 'package:myroad/services/json_import_service.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('export and reimport region produces equivalent data', () async {
    final regionDao = RegionDao(db);
    final areaDao = AreaDao(db);
    final spotDao = SpotDao(db);

    final regionId = await regionDao.insertRegion('Japan', 'Research');
    final areaId = await areaDao.insertArea('Shinjuku', 'city', regionId: regionId);
    await spotDao.insertSpot(
      name: 'Golden Gai',
      areaId: areaId,
      type: 'spot',
      lat: 35.69,
      lng: 139.70,
    );

    final exportService = JsonExportService(db);
    final json = await exportService.exportRegion(regionId);

    expect(json['schemaVersion'], 1);
    expect(json['type'], 'region');
    expect(json['data']['name'], 'Japan');
    expect((json['data']['areas'] as List).length, 1);
    expect((json['data']['areas'] as List)[0]['spots'].length, 1);

    final importService = JsonImportService(db);
    final newRegionId = await importService.importRegion(json);

    // Same DB: reuses existing entities by ID
    expect(newRegionId, regionId);

    // Import into a fresh DB: creates new entities with same IDs
    final db2 = AppDatabase(NativeDatabase.memory());
    final importService2 = JsonImportService(db2);
    final freshRegionId = await importService2.importRegion(json);

    final freshRegion = await RegionDao(db2).getById(freshRegionId);
    expect(freshRegion, isNotNull);
    expect(freshRegion!.name, 'Japan');

    final freshAreas = await AreaDao(db2).watchByRegion(freshRegionId).first;
    expect(freshAreas.length, 1);
    expect(freshAreas[0].name, 'Shinjuku');

    final freshSpots = await SpotDao(db2).watchByArea(freshAreas[0].id).first;
    expect(freshSpots.length, 1);
    expect(freshSpots[0].name, 'Golden Gai');
    expect(freshSpots[0].lat, 35.69);

    await db2.close();
  });

  test('export and reimport trip preserves structure', () async {
    final regionDao = RegionDao(db);
    final areaDao = AreaDao(db);

    final regionId = await regionDao.insertRegion('Tokyo', null);
    await areaDao.insertArea('Shibuya', 'city', regionId: regionId);

    final tripDao = TripDao(db);
    final tripId = await tripDao.insertTrip(name: 'Tokyo Trip');
    await regionDao.addToTrip(regionId, tripId);

    final exportService = JsonExportService(db);
    final json = await exportService.exportTrip(tripId);

    expect(json['schemaVersion'], 1);
    expect(json['type'], 'trip');
    expect(json['data']['name'], 'Tokyo Trip');
    expect((json['data']['regions'] as List).length, 1);

    final importService = JsonImportService(db);
    final newTripId = await importService.importTrip(json);
    expect(newTripId, isNot(tripId));
  });
}
