import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/database/dao/region_dao.dart';
import 'package:myroad/database/dao/zone_dao.dart';
import 'package:myroad/database/dao/spot_dao.dart';

void main() {
  late AppDatabase db;
  late ItineraryDao itineraryDao;
  late String tripId;
  late String spotId;
  late String zoneId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    itineraryDao = ItineraryDao(db);
    final tripDao = TripDao(db);
    final regionDao = RegionDao(db);
    final zoneDao = ZoneDao(db);
    final spotDao = SpotDao(db);

    tripId = await tripDao.insertTrip(
        name: 'Test', transportPreference: 'walk', planMode: 'coarse');
    final regionId = await regionDao.insertRegion('R', null);
    zoneId = await zoneDao.insertZone('Z', 'city', regionId: regionId);
    spotId = await spotDao.insertSpot(
        name: 'Spot', zoneId: zoneId, type: 'spot', lat: 0, lng: 0);
  });

  tearDown(() async => await db.close());

  test('initialize days and add item', () async {
    await itineraryDao.initializeDays(tripId, 3);
    final days = await itineraryDao.watchDays(tripId).first;
    expect(days.length, 3);

    await itineraryDao.addItemToDay(
      dayId: days[0].id,
      spotId: spotId,
      zoneId: zoneId,
      order: 0,
    );

    final items = await itineraryDao.watchDayItems(days[0].id).first;
    expect(items.length, 1);
  });

  test('move item between days', () async {
    await itineraryDao.initializeDays(tripId, 2);
    final days = await itineraryDao.watchDays(tripId).first;

    final itemId = await itineraryDao.addItemToDay(
      dayId: days[0].id,
      spotId: spotId,
      zoneId: zoneId,
      order: 0,
    );

    await itineraryDao.moveItem(itemId,
        toDayId: days[1].id, newOrder: 0);

    final day1Items = await itineraryDao.watchDayItems(days[0].id).first;
    final day2Items = await itineraryDao.watchDayItems(days[1].id).first;
    expect(day1Items.length, 0);
    expect(day2Items.length, 1);
  });

  test('remove item', () async {
    await itineraryDao.initializeDays(tripId, 1);
    final days = await itineraryDao.watchDays(tripId).first;

    final itemId = await itineraryDao.addItemToDay(
      dayId: days[0].id,
      spotId: spotId,
      zoneId: zoneId,
      order: 0,
    );

    await itineraryDao.removeItem(itemId);
    final items = await itineraryDao.watchDayItems(days[0].id).first;
    expect(items, isEmpty);
  });

  test('set item times', () async {
    await itineraryDao.initializeDays(tripId, 1);
    final days = await itineraryDao.watchDays(tripId).first;

    final itemId = await itineraryDao.addItemToDay(
      dayId: days[0].id,
      spotId: spotId,
      zoneId: zoneId,
      order: 0,
    );

    await itineraryDao.setItemTimes(itemId,
        startMinutes: 600, endMinutes: 660);

    final items = await itineraryDao.watchDayItems(days[0].id).first;
    expect(items[0].startTimeMinutes, 600);
    expect(items[0].endTimeMinutes, 660);
  });
}
