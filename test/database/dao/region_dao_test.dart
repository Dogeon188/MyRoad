import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/dao/trip_dao.dart';

void main() {
  late AppDatabase db;
  late RegionDao regionDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    regionDao = RegionDao(db);
  });

  tearDown(() async => await db.close());

  test('add and watch regions by trip', () async {
    final tripDao = TripDao(db);
    final tripId = await tripDao.insertTrip(name: 'Test Trip');
    final r1 = await regionDao.insertRegion('Tokyo Area', null);
    final r2 = await regionDao.insertRegion('Osaka Area', null);

    await regionDao.addToTrip(r1, tripId);
    await regionDao.addToTrip(r2, tripId);

    final regions = await regionDao.watchByTrip(tripId).first;
    expect(regions.length, 2);
    expect(regions[0].name, 'Tokyo Area');
  });

  test('reorder regions in trip', () async {
    final tripDao = TripDao(db);
    final tripId = await tripDao.insertTrip(name: 'Test Trip');
    final id1 = await regionDao.insertRegion('A', null);
    final id2 = await regionDao.insertRegion('B', null);

    await regionDao.addToTrip(id1, tripId);
    await regionDao.addToTrip(id2, tripId);
    await regionDao.reorderInTrip(tripId, [id2, id1]);

    final regions = await regionDao.watchByTrip(tripId).first;
    expect(regions[0].id, id2);
    expect(regions[1].id, id1);
  });

  test('remove region from trip', () async {
    final tripDao = TripDao(db);
    final tripId = await tripDao.insertTrip(name: 'Test Trip');
    final regionId = await regionDao.insertRegion('Tokyo', null);

    await regionDao.addToTrip(regionId, tripId);
    await regionDao.removeFromTrip(regionId, tripId);

    final regions = await regionDao.watchByTrip(tripId).first;
    expect(regions.isEmpty, true);
  });

  test('set and update icon', () async {
    final id = await regionDao.insertRegion('Tokyo', null, iconCode: 1);

    var region = await regionDao.getById(id);
    expect(region!.iconCode, 1);

    await regionDao.updateRegion(id, iconCode: const Value(null));
    region = await regionDao.getById(id);
    expect(region!.iconCode, null);
  });
}
