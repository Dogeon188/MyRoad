import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/dao/area_dao.dart';

void main() {
  late AppDatabase db;
  late RegionDao regionDao;
  late AreaDao areaDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    regionDao = RegionDao(db);
    areaDao = AreaDao(db);
  });

  tearDown(() async => await db.close());

  test('insert and watch areas by region', () async {
    final regionId = await regionDao.insertRegion('Test Region', null);
    await areaDao.insertArea('Shinjuku', 'neighborhood', regionId: regionId);
    await areaDao.insertArea('Akihabara', 'neighborhood', regionId: regionId);

    final areas = await areaDao.watchByRegion(regionId).first;
    expect(areas.length, 2);
    expect(areas[0].name, 'Shinjuku');
  });

  test('reorder areas', () async {
    final regionId = await regionDao.insertRegion('Test Region', null);
    final id1 = await areaDao.insertArea('First', 'city', regionId: regionId);
    final id2 = await areaDao.insertArea('Second', 'city', regionId: regionId);

    await areaDao.reorder([id2, id1]);

    final areas = await areaDao.watchByRegion(regionId).first;
    expect(areas[0].id, id2);
    expect(areas[1].id, id1);
  });

  test('set and update icon', () async {
    final regionId = await regionDao.insertRegion('Test Region', null);
    final areaId = await areaDao.insertArea(
      'Shinjuku',
      'city',
      regionId: regionId,
    );

    await areaDao.updateArea(areaId, iconCode: const Value(1));
    var area = await areaDao.getById(areaId);
    expect(area!.iconCode, 1);

    await areaDao.updateArea(areaId, iconCode: const Value(null));
    area = await areaDao.getById(areaId);
    expect(area!.iconCode, null);
  });
}
