import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';

void main() {
  late AppDatabase db;
  late TripDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = TripDao(db);
  });

  tearDown(() async => await db.close());

  test('insert and retrieve trip', () async {
    final id = await dao.insertTrip(name: 'Japan 2026', transportPreference: 'transit', planMode: 'detailed');
    final trip = await dao.getById(id);
    expect(trip, isNotNull);
    expect(trip!.name, 'Japan 2026');
    expect(trip.planMode, 'detailed');
    expect(trip.transportPreference, 'transit');
  });

  test('watchAll returns all trips', () async {
    await dao.insertTrip(name: 'First');
    await dao.insertTrip(name: 'Second');
    final trips = await dao.watchAll().first;
    expect(trips.length, 2);
  });

  test('updateTrip', () async {
    final id = await dao.insertTrip(name: 'Old');
    await dao.updateTrip(id, name: 'New', planMode: 'detailed');
    final trip = await dao.getById(id);
    expect(trip!.name, 'New');
    expect(trip.planMode, 'detailed');
  });

  test('deleteTrip removes trip and its region references', () async {
    final regionDao = RegionDao(db);
    final tripId = await dao.insertTrip(name: 'Test');
    final regionId = await regionDao.insertRegion('Tokyo', null);
    await regionDao.addToTrip(regionId, tripId);

    await dao.deleteTrip(tripId);

    final trip = await dao.getById(tripId);
    expect(trip, isNull);

    // Region still exists (shared), but trip reference is gone
    final region = await regionDao.getById(regionId);
    expect(region, isNotNull);
    final tripRegions = await regionDao.watchByTrip(tripId).first;
    expect(tripRegions, isEmpty);
  });
}
