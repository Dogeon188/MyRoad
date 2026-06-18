import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/roi_dao.dart';
import 'package:myroad/database/dao/zone_dao.dart';

void main() {
  late AppDatabase db;
  late RoiDao roiDao;
  late ZoneDao zoneDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    roiDao = RoiDao(db);
    zoneDao = ZoneDao(db);
  });

  tearDown(() async => await db.close());

  test('insert and watch zones by ROI', () async {
    final roiId = await roiDao.insertRoi('Test ROI', null);
    await zoneDao.insertZone('Tokyo Area', roiId: roiId);
    await zoneDao.insertZone('Osaka Area', roiId: roiId);

    final zones = await zoneDao.watchByRoi(roiId).first;
    expect(zones.length, 2);
    expect(zones[0].name, 'Tokyo Area');
  });

  test('reorder zones', () async {
    final roiId = await roiDao.insertRoi('Test ROI', null);
    final id1 = await zoneDao.insertZone('First', roiId: roiId);
    final id2 = await zoneDao.insertZone('Second', roiId: roiId);

    await zoneDao.reorder([id2, id1]);

    final zones = await zoneDao.watchByRoi(roiId).first;
    expect(zones[0].id, id2);
    expect(zones[1].id, id1);
  });
}
