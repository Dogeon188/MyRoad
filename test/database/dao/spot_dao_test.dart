import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/dao/area_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';

void main() {
  late AppDatabase db;
  late SpotDao spotDao;
  late String areaId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final regionDao = RegionDao(db);
    final areaDao = AreaDao(db);
    spotDao = SpotDao(db);

    final regionId = await regionDao.insertRegion('Test', null);
    areaId = await areaDao.insertArea('Area', 'city', regionId: regionId);
  });

  tearDown(() async => await db.close());

  test('insert and watch spots by zone', () async {
    await spotDao.insertSpot(
      name: 'Tokyo Tower',
      areaId: areaId,
      type: 'spot',
      lat: 35.6586,
      lng: 139.7454,
    );

    final spots = await spotDao.watchByArea(areaId).first;
    expect(spots.length, 1);
    expect(spots[0].name, 'Tokyo Tower');
  });

  test('add custom info to spot', () async {
    final spotId = await spotDao.insertSpot(
      name: 'Spot',
      areaId: areaId,
      type: 'spot',
      lat: 0,
      lng: 0,
    );

    await spotDao.addCustomInfo(spotId, 'Ticket', '¥1000');
    final infos = await spotDao.getCustomInfos(spotId);
    expect(infos.length, 1);
    expect(infos[0].label, 'Ticket');
    expect(infos[0].value, '¥1000');
  });

  test('add opening hours to spot', () async {
    final spotId = await spotDao.insertSpot(
      name: 'Spot',
      areaId: areaId,
      type: 'spot',
      lat: 0,
      lng: 0,
    );

    await spotDao.addOpeningHours(spotId, day: 0, openMinutes: 540, closeMinutes: 1080);
    final hours = await spotDao.getOpeningHours(spotId);
    expect(hours.length, 1);
    expect(hours[0].openMinutes, 540);
  });

  test('delete spot cascades', () async {
    final spotId = await spotDao.insertSpot(
      name: 'Spot',
      areaId: areaId,
      type: 'spot',
      lat: 0,
      lng: 0,
    );
    await spotDao.addCustomInfo(spotId, 'Key', 'Val');
    await spotDao.deleteSpot(spotId);

    final spot = await spotDao.getById(spotId);
    expect(spot, isNull);
  });
}
