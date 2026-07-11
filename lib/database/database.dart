import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:myroad/database/tables.dart';

part 'database.g.dart';

const _uuid = Uuid();

@DriftDatabase(
  tables: [
    Regions,
    Trips,
    TripRegions,
    Areas,
    Spots,
    SpotOpeningHoursEntries,
    SpotPhotos,
    Transports,
    ItineraryDays,
    DayItems,
    HotelStays,
    TripSpotTimes,
    TravelPasses,
    AlbumEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults() : super(_openConnection());

  @override
  int get schemaVersion => 27;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 4) {
        await customStatement(
          'CREATE TABLE day_items_new ('
          'id TEXT NOT NULL PRIMARY KEY, '
          'day_id TEXT NOT NULL REFERENCES itinerary_days(id), '
          'spot_id TEXT REFERENCES spots(id), '
          'zone_id TEXT NOT NULL REFERENCES zones(id), '
          '"order" INTEGER NOT NULL, '
          'start_time_minutes INTEGER, '
          'end_time_minutes INTEGER, '
          'transport_to_next_id TEXT REFERENCES transports(id))',
        );
        await customStatement(
          'INSERT INTO day_items_new SELECT * FROM day_items',
        );
        await customStatement('DROP TABLE day_items');
        await customStatement('ALTER TABLE day_items_new RENAME TO day_items');
      }
      if (from < 5) {
        await customStatement(
          'ALTER TABLE transports ADD COLUMN route_name TEXT',
        );
        await customStatement('ALTER TABLE transports ADD COLUMN price TEXT');
      }
      if (from < 6) {
        // Make zone_id nullable, add item_type
        await customStatement(
          'CREATE TABLE day_items_new ('
          'id TEXT NOT NULL PRIMARY KEY, '
          'day_id TEXT NOT NULL REFERENCES itinerary_days(id), '
          'spot_id TEXT REFERENCES spots(id), '
          'zone_id TEXT REFERENCES zones(id), '
          'item_type TEXT NOT NULL DEFAULT \'zone\', '
          '"order" INTEGER NOT NULL, '
          'start_time_minutes INTEGER, '
          'end_time_minutes INTEGER, '
          'transport_to_next_id TEXT REFERENCES transports(id))',
        );
        await customStatement(
          'INSERT INTO day_items_new (id, day_id, spot_id, zone_id, item_type, "order", start_time_minutes, end_time_minutes, transport_to_next_id) '
          'SELECT id, day_id, spot_id, zone_id, \'zone\', "order", start_time_minutes, end_time_minutes, transport_to_next_id FROM day_items',
        );
        await customStatement('DROP TABLE day_items');
        await customStatement('ALTER TABLE day_items_new RENAME TO day_items');
      }
      if (from < 7) {
        // Make lat/lng nullable on spots for online schedules
        await customStatement(
          'CREATE TABLE spots_new ('
          'id TEXT NOT NULL PRIMARY KEY, '
          'zone_id TEXT NOT NULL REFERENCES zones(id), '
          'name TEXT NOT NULL, '
          'type TEXT NOT NULL DEFAULT \'spot\', '
          'lat REAL, '
          'lng REAL, '
          'address TEXT NOT NULL DEFAULT \'\', '
          'google_place_id TEXT, '
          'preview_image_url TEXT, '
          '"order" INTEGER, '
          'notes TEXT NOT NULL DEFAULT \'\', '
          'estimated_visit_duration_minutes INTEGER NOT NULL DEFAULT 60, '
          'buffer_time_minutes INTEGER NOT NULL DEFAULT 15, '
          'review TEXT)',
        );
        await customStatement('INSERT INTO spots_new SELECT * FROM spots');
        await customStatement('DROP TABLE spots');
        await customStatement('ALTER TABLE spots_new RENAME TO spots');
      }
      if (from < 8) {
        // Rename zones → areas
        await customStatement('ALTER TABLE zones RENAME TO areas');
        await customStatement(
          'ALTER TABLE spots RENAME COLUMN zone_id TO area_id',
        );
        await customStatement(
          'ALTER TABLE day_items RENAME COLUMN zone_id TO area_id',
        );
        await customStatement(
          "UPDATE day_items SET item_type = 'area' WHERE item_type = 'zone'",
        );
      }
      if (from < 9) {
        await customStatement(
          'CREATE TABLE trip_spot_times ('
          'trip_id TEXT NOT NULL REFERENCES trips(id), '
          'spot_id TEXT NOT NULL REFERENCES spots(id), '
          'start_time_minutes INTEGER NOT NULL, '
          'PRIMARY KEY (trip_id, spot_id))',
        );
      }
      if (from < 10) {
        if (from >= 9) {
          // Table exists from v9 — recreate with nullable start_time_minutes + new column
          await customStatement(
            'CREATE TABLE trip_spot_times_new ('
            'trip_id TEXT NOT NULL REFERENCES trips(id), '
            'spot_id TEXT NOT NULL REFERENCES spots(id), '
            'start_time_minutes INTEGER, '
            'after_transport INTEGER NOT NULL DEFAULT 0, '
            'PRIMARY KEY (trip_id, spot_id))',
          );
          await customStatement(
            'INSERT INTO trip_spot_times_new (trip_id, spot_id, start_time_minutes) '
            'SELECT trip_id, spot_id, start_time_minutes FROM trip_spot_times',
          );
          await customStatement('DROP TABLE trip_spot_times');
          await customStatement(
            'ALTER TABLE trip_spot_times_new RENAME TO trip_spot_times',
          );
        }
        await customStatement(
          'ALTER TABLE itinerary_days ADD COLUMN departure_time_minutes INTEGER',
        );
        await customStatement(
          'ALTER TABLE itinerary_days ADD COLUMN arrival_time_minutes INTEGER',
        );
      }
      if (from < 11) {
        await customStatement('ALTER TABLE regions ADD COLUMN review TEXT');
        await customStatement('ALTER TABLE areas ADD COLUMN review TEXT');
      }
      if (from < 12) {
        await customStatement(
          'ALTER TABLE trip_spot_times ADD COLUMN skipped INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (from < 13) {
        await customStatement('ALTER TABLE regions ADD COLUMN rating INTEGER');
        await customStatement('ALTER TABLE areas ADD COLUMN rating INTEGER');
        await customStatement('ALTER TABLE spots ADD COLUMN rating INTEGER');
      }
      if (from < 14) {
        await customStatement('ALTER TABLE spots ADD COLUMN price TEXT');
      }
      if (from < 15) {
        await customStatement(
          "ALTER TABLE regions ADD COLUMN currency TEXT NOT NULL DEFAULT 'JPY'",
        );
      }
      if (from < 16) {
        await customStatement(
          'ALTER TABLE regions ADD COLUMN source_region_id TEXT REFERENCES regions(id)',
        );
      }
      if (from < 17) {
        await customStatement(
          'CREATE TABLE travel_passes ('
          'id TEXT NOT NULL PRIMARY KEY, '
          'trip_id TEXT NOT NULL REFERENCES trips(id), '
          'name TEXT NOT NULL, '
          'url TEXT, '
          'price TEXT, '
          'start_day INTEGER NOT NULL DEFAULT 1, '
          'end_day INTEGER NOT NULL DEFAULT 1)',
        );
        await customStatement(
          'ALTER TABLE transports ADD COLUMN pass_id TEXT REFERENCES travel_passes(id)',
        );
        await customStatement(
          'ALTER TABLE day_items ADD COLUMN pass_id TEXT REFERENCES travel_passes(id)',
        );
      }
      if (from < 18) {
        await customStatement(
          'ALTER TABLE travel_passes ADD COLUMN price TEXT',
        );
      }
      if (from < 19) {
        await customStatement(
          "ALTER TABLE travel_passes ADD COLUMN bought INTEGER NOT NULL DEFAULT 0",
        );
        await customStatement("ALTER TABLE travel_passes ADD COLUMN note TEXT");
      }
      if (from < 20) {
        await customStatement('ALTER TABLE spots ADD COLUMN icon_code INTEGER');
        await customStatement(
          'ALTER TABLE spots ADD COLUMN color_value INTEGER',
        );
      }
      if (from < 21) {
        await customStatement('ALTER TABLE spots ADD COLUMN url TEXT');
      }
      if (from < 22) {
        await customStatement('DROP TABLE IF EXISTS spot_custom_infos');
      }
      if (from < 23) {
        await customStatement('ALTER TABLE transports ADD COLUMN url TEXT');
      }
      if (from < 24) {
        await customStatement(
          'ALTER TABLE regions ADD COLUMN icon_code INTEGER',
        );
        await customStatement(
          'ALTER TABLE regions ADD COLUMN color_value INTEGER',
        );
        await customStatement('ALTER TABLE areas ADD COLUMN icon_code INTEGER');
        await customStatement(
          'ALTER TABLE areas ADD COLUMN color_value INTEGER',
        );
      }
      if (from < 25) {
        // Color customization removed — icon-only from here on.
        await customStatement('ALTER TABLE regions DROP COLUMN color_value');
        await customStatement('ALTER TABLE areas DROP COLUMN color_value');
        await customStatement('ALTER TABLE spots DROP COLUMN color_value');
      }
      if (from < 26) {
        await customStatement('ALTER TABLE trips ADD COLUMN icon_code INTEGER');
      }
      if (from < 27) {
        await customStatement(
          'ALTER TABLE spots ADD COLUMN color_value INTEGER',
        );
      }
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'myroad',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.defaults();
  ref.onDispose(() => db.close());
  return db;
});
