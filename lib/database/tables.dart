import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Rois extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

class Trips extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get name => text()();
  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get transportPreference => text().withDefault(const Constant('walk'))();
  IntColumn get bufferTimeDefaultMinutes => integer().withDefault(const Constant(15))();
  TextColumn get planMode => text().withDefault(const Constant('coarse'))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

class TripRoiSources extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get roiId => text().references(Rois, #id)();
  DateTimeColumn get importedAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

// Region: big grouping (e.g. "Tokyo Area"). Can span multiple days.
class Regions extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get roiId => text().nullable().references(Rois, #id)();
  TextColumn get tripId => text().nullable().references(Trips, #id)();
  TextColumn get name => text()();
  IntColumn get order => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// Zone: smaller area (e.g. "Shinjuku"). Must fit within 1 day.
class Zones extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get roiId => text().nullable().references(Rois, #id)();
  TextColumn get regionId => text().nullable().references(Regions, #id)();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('city'))();
  IntColumn get order => integer().withDefault(const Constant(0))();
  RealColumn get boundsSouth => real().nullable()();
  RealColumn get boundsWest => real().nullable()();
  RealColumn get boundsNorth => real().nullable()();
  RealColumn get boundsEast => real().nullable()();
  IntColumn get estimatedDurationMinutes => integer().withDefault(const Constant(480))();

  @override
  Set<Column> get primaryKey => {id};
}

class Spots extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get zoneId => text().references(Zones, #id)();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('spot'))();
  RealColumn get lat => real()();
  RealColumn get lng => real()();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get googlePlaceId => text().nullable()();
  TextColumn get previewImageUrl => text().nullable()();
  IntColumn get order => integer().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get estimatedVisitDurationMinutes => integer().withDefault(const Constant(60))();
  IntColumn get bufferTimeMinutes => integer().withDefault(const Constant(15))();
  TextColumn get review => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SpotCustomInfos extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get spotId => text().references(Spots, #id)();
  TextColumn get label => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class SpotOpeningHoursEntries extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get spotId => text().references(Spots, #id)();
  IntColumn get day => integer()();
  IntColumn get openMinutes => integer()();
  IntColumn get closeMinutes => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class SpotPhotos extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get spotId => text().references(Spots, #id)();
  TextColumn get uri => text()();
  TextColumn get caption => text().nullable()();
  DateTimeColumn get takenAt => dateTime().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Transports extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get fromSpotId => text().references(Spots, #id)();
  TextColumn get toSpotId => text().references(Spots, #id)();
  TextColumn get mode => text().withDefault(const Constant('walk'))();
  IntColumn get estimatedDurationMinutes => integer()();
  RealColumn get distanceMeters => real().nullable()();
  TextColumn get routePolyline => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ItineraryDays extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get tripId => text().references(Trips, #id)();
  DateTimeColumn get date => dateTime().nullable()();
  IntColumn get dayNumber => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class DayItems extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get dayId => text().references(ItineraryDays, #id)();
  TextColumn get spotId => text().references(Spots, #id)();
  TextColumn get zoneId => text().references(Zones, #id)();
  IntColumn get order => integer()();
  IntColumn get startTimeMinutes => integer().nullable()();
  IntColumn get endTimeMinutes => integer().nullable()();
  TextColumn get transportToNextId => text().nullable().references(Transports, #id)();

  @override
  Set<Column> get primaryKey => {id};
}

class HotelStays extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get spotId => text().references(Spots, #id)();
  DateTimeColumn get checkInDateTime => dateTime()();
  DateTimeColumn get checkOutDateTime => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class AlbumEntries extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get spotId => text().references(Spots, #id)();
  TextColumn get photoId => text().references(SpotPhotos, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}
