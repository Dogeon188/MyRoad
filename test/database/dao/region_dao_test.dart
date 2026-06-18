import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/roi_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';

void main() {
  late AppDatabase db;
  late RoiDao roiDao;
  late RegionDao regionDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    roiDao = RoiDao(db);
    regionDao = RegionDao(db);
  });

  tearDown(() async => await db.close());

  test('insert and watch regions by ROI', () async {
    final roiId = await roiDao.insertRoi('Test', null);
    await regionDao.insertRegion('Tokyo Area', roiId: roiId);
    await regionDao.insertRegion('Osaka Area', roiId: roiId);

    final regions = await regionDao.watchByRoi(roiId).first;
    expect(regions.length, 2);
    expect(regions[0].name, 'Tokyo Area');
  });

  test('reorder regions', () async {
    final roiId = await roiDao.insertRoi('Test', null);
    final id1 = await regionDao.insertRegion('A', roiId: roiId);
    final id2 = await regionDao.insertRegion('B', roiId: roiId);

    await regionDao.reorder([id2, id1]);

    final regions = await regionDao.watchByRoi(roiId).first;
    expect(regions[0].id, id2);
    expect(regions[1].id, id1);
  });
}
