import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/dao/zone_dao.dart';

void main() {
  late AppDatabase db;
  late RegionDao regionDao;
  late ZoneDao zoneDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    regionDao = RegionDao(db);
    zoneDao = ZoneDao(db);
  });

  tearDown(() async => await db.close());

  test('insert and watch zones by region', () async {
    final regionId = await regionDao.insertRegion('Test Region', null);
    await zoneDao.insertZone('Shinjuku', 'neighborhood', regionId: regionId);
    await zoneDao.insertZone('Akihabara', 'neighborhood', regionId: regionId);

    final zones = await zoneDao.watchByRegion(regionId).first;
    expect(zones.length, 2);
    expect(zones[0].name, 'Shinjuku');
  });

  test('reorder zones', () async {
    final regionId = await regionDao.insertRegion('Test Region', null);
    final id1 = await zoneDao.insertZone('First', 'city', regionId: regionId);
    final id2 = await zoneDao.insertZone('Second', 'city', regionId: regionId);

    await zoneDao.reorder([id2, id1]);

    final zones = await zoneDao.watchByRegion(regionId).first;
    expect(zones[0].id, id2);
    expect(zones[1].id, id1);
  });
}
