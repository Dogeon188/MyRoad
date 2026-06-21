import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Regions extends Table {
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

class TripRegions extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get regionId => text().references(Regions, #id)();
  IntColumn get order => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// Area: smaller region (e.g. "Shinjuku"). Must fit within 1 day.
class Areas extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get regionId => text().references(Regions, #id)();
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
  TextColumn get areaId => text().references(Areas, #id)();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('spot'))();
  RealColumn get lat => real().nullable()();
  RealColumn get lng => real().nullable()();
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
  TextColumn get routeName => text().nullable()();
  TextColumn get price => text().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ItineraryDays extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get tripId => text().references(Trips, #id)();
  DateTimeColumn get date => dateTime().nullable()();
  IntColumn get dayNumber => integer()();
  IntColumn get departureTimeMinutes => integer().nullable()();
  IntColumn get arrivalTimeMinutes => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class DayItems extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get dayId => text().references(ItineraryDays, #id)();
  TextColumn get spotId => text().nullable().references(Spots, #id)();
  TextColumn get areaId => text().nullable().references(Areas, #id)();
  TextColumn get itemType => text().withDefault(const Constant('area'))();
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

class TripSpotTimes extends Table {
  TextColumn get tripId => text().references(Trips, #id)();
  TextColumn get spotId => text().references(Spots, #id)();
  IntColumn get startTimeMinutes => integer().nullable()();
  BoolColumn get afterTransport => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {tripId, spotId};
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
