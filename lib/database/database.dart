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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // ponytail: no prod data yet, just recreate
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      await m.deleteTable('album_entries');
      await m.deleteTable('hotel_stays');
      await m.deleteTable('day_items');
      await m.deleteTable('itinerary_days');
      await m.deleteTable('transports');
      await m.deleteTable('spot_photos');
      await m.deleteTable('spot_opening_hours_entries');
      await m.deleteTable('spot_custom_infos');
      await m.deleteTable('spots');
      await m.deleteTable('zones');
      await m.deleteTable('trip_regions');
      await m.deleteTable('trip_roi_sources');
      await m.deleteTable('regions');
      await m.deleteTable('trips');
      await m.deleteTable('rois');
      await m.createAll();
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
