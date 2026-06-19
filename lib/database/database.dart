import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:myroad/database/tables.dart';

part 'database.g.dart';

const _uuid = Uuid();

@DriftDatabase(tables: [
  Regions,
  Trips,
  TripRegions,
  Zones,
  Spots,
  SpotCustomInfos,
  SpotOpeningHoursEntries,
  SpotPhotos,
  Transports,
  ItineraryDays,
  DayItems,
  HotelStays,
  AlbumEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  AppDatabase.defaults() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 4) {
        // Make spot_id nullable: SQLite can't ALTER COLUMN, so recreate the table
        await customStatement('CREATE TABLE day_items_new ('
            'id TEXT NOT NULL PRIMARY KEY, '
            'day_id TEXT NOT NULL REFERENCES itinerary_days(id), '
            'spot_id TEXT REFERENCES spots(id), '
            'zone_id TEXT NOT NULL REFERENCES zones(id), '
            '"order" INTEGER NOT NULL, '
            'start_time_minutes INTEGER, '
            'end_time_minutes INTEGER, '
            'transport_to_next_id TEXT REFERENCES transports(id))');
        await customStatement(
            'INSERT INTO day_items_new SELECT * FROM day_items');
        await customStatement('DROP TABLE day_items');
        await customStatement(
            'ALTER TABLE day_items_new RENAME TO day_items');
      }
    },
  );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'myroad.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.defaults();
  ref.onDispose(() => db.close());
  return db;
});
