import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/database/dao/trip_dao.dart';

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

  test('deleteTrip removes trip', () async {
    final id = await dao.insertTrip(name: 'Test');
    await dao.deleteTrip(id);
    final trip = await dao.getById(id);
    expect(trip, isNull);
  });

  test('deleteTrip cascades to regions and zones', () async {
    final id = await dao.insertTrip(name: 'Test');
    // Insert a region owned by trip
    await db.into(db.regions).insert(RegionsCompanion.insert(name: 'Tokyo', tripId: Value(id)));
    await dao.deleteTrip(id);
    final regions = await (db.select(db.regions)..where((t) => t.tripId.equals(id))).get();
    expect(regions, isEmpty);
  });
}
