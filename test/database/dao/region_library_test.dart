import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/region_dao.dart';

void main() {
  late AppDatabase db;
  late RegionDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = RegionDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('insert and retrieve region', () async {
    final id = await dao.insertRegion('Japan Trip Research', 'Spots for Japan');
    final region = await dao.getById(id);
    expect(region != null, true);
    expect(region!.name, 'Japan Trip Research');
    expect(region.description, 'Spots for Japan');
  });

  test('watchAll returns stream of regions', () async {
    await dao.insertRegion('Region 1', null);
    await dao.insertRegion('Region 2', null);

    final regions = await dao.watchAll().first;
    expect(regions.length, 2);
  });

  test('update region', () async {
    final id = await dao.insertRegion('Old Name', null);
    await dao.updateRegion(id, name: 'New Name');

    final region = await dao.getById(id);
    expect(region!.name, 'New Name');
  });

  test('delete region', () async {
    final id = await dao.insertRegion('To Delete', null);
    await dao.deleteRegion(id);

    final region = await dao.getById(id);
    expect(region == null, true);
  });
}
