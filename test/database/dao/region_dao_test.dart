import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/roi_dao.dart';
import 'package:myroad/database/dao/zone_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';

void main() {
  late AppDatabase db;
  late RoiDao roiDao;
  late ZoneDao zoneDao;
  late RegionDao regionDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    roiDao = RoiDao(db);
    zoneDao = ZoneDao(db);
    regionDao = RegionDao(db);
  });

  tearDown(() async => await db.close());

  test('insert and watch regions by zone', () async {
    final roiId = await roiDao.insertRoi('Test', null);
    final zoneId = await zoneDao.insertZone('Zone', roiId: roiId);
    await regionDao.insertRegion('Shinjuku', zoneId, 'neighborhood');

    final regions = await regionDao.watchByZone(zoneId).first;
    expect(regions.length, 1);
    expect(regions[0].name, 'Shinjuku');
    expect(regions[0].type, 'neighborhood');
  });

  test('reorder regions', () async {
    final roiId = await roiDao.insertRoi('Test', null);
    final zoneId = await zoneDao.insertZone('Zone', roiId: roiId);
    final id1 = await regionDao.insertRegion('A', zoneId, 'city');
    final id2 = await regionDao.insertRegion('B', zoneId, 'city');

    await regionDao.reorder([id2, id1]);

    final regions = await regionDao.watchByZone(zoneId).first;
    expect(regions[0].id, id2);
  });
}
