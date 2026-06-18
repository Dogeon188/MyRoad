import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/roi_dao.dart';
import 'package:myroad/database/dao/zone_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';

void main() {
  late AppDatabase db;
  late SpotDao spotDao;
  late String zoneId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final roiDao = RoiDao(db);
    final zoneDao = ZoneDao(db);
    spotDao = SpotDao(db);

    final roiId = await roiDao.insertRoi('Test', null);
    zoneId = await zoneDao.insertZone('Zone', 'city', roiId: roiId);
  });

  tearDown(() async => await db.close());

  test('insert and watch spots by zone', () async {
    await spotDao.insertSpot(
      name: 'Tokyo Tower',
      zoneId: zoneId,
      type: 'spot',
      lat: 35.6586,
      lng: 139.7454,
    );

    final spots = await spotDao.watchByZone(zoneId).first;
    expect(spots.length, 1);
    expect(spots[0].name, 'Tokyo Tower');
  });

  test('add custom info to spot', () async {
    final spotId = await spotDao.insertSpot(
      name: 'Spot',
      zoneId: zoneId,
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
      zoneId: zoneId,
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
      zoneId: zoneId,
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
