import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';

class ItineraryDao {
  final AppDatabase _db;

  ItineraryDao(this._db);

  Stream<List<ItineraryDay>> watchDays(String tripId) {
    return (_db.select(_db.itineraryDays)
          ..where((t) => t.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.dayNumber)]))
        .watch();
  }

  Stream<List<DayItem>> watchDayItems(String dayId) {
    return (_db.select(_db.dayItems)
          ..where((t) => t.dayId.equals(dayId))
          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
        .watch();
  }

  Future<void> initializeDays(String tripId, int dayCount) async {
    for (var i = 0; i < dayCount; i++) {
      await _db.into(_db.itineraryDays).insert(
            ItineraryDaysCompanion.insert(tripId: tripId, dayNumber: i + 1),
          );
    }
  }

  Future<String> addItemToDay({
    required String dayId,
    required String spotId,
    required String zoneId,
    required int order,
  }) async {
    final item = await _db.into(_db.dayItems).insertReturning(
          DayItemsCompanion.insert(
            dayId: dayId,
            spotId: spotId,
            zoneId: zoneId,
            order: order,
          ),
        );
    return item.id;
  }

  Future<void> moveItem(String itemId,
      {required String toDayId, required int newOrder}) {
    return (_db.update(_db.dayItems)..where((t) => t.id.equals(itemId))).write(
      DayItemsCompanion(
        dayId: Value(toDayId),
        order: Value(newOrder),
      ),
    );
  }

  Future<void> removeItem(String itemId) {
    return (_db.delete(_db.dayItems)..where((t) => t.id.equals(itemId))).go();
  }

  Future<void> setItemTimes(String itemId,
      {int? startMinutes, int? endMinutes}) {
    return (_db.update(_db.dayItems)..where((t) => t.id.equals(itemId))).write(
      DayItemsCompanion(
        startTimeMinutes: Value(startMinutes),
        endTimeMinutes: Value(endMinutes),
      ),
    );
  }

  Future<void> addHotelStay({
    required String tripId,
    required String spotId,
    required DateTime checkIn,
    required DateTime checkOut,
  }) async {
    await _db.into(_db.hotelStays).insert(
          HotelStaysCompanion.insert(
            tripId: tripId,
            spotId: spotId,
            checkInDateTime: checkIn,
            checkOutDateTime: checkOut,
          ),
        );
  }

  Stream<List<HotelStay>> watchHotelStays(String tripId) {
    return (_db.select(_db.hotelStays)
          ..where((t) => t.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.checkInDateTime)]))
        .watch();
  }

  Future<void> deleteHotelStay(String id) {
    return (_db.delete(_db.hotelStays)..where((t) => t.id.equals(id))).go();
  }

  // ponytail: day number encoded as DateTime(1970,1,dayNumber), real dates when trip has them
  static DateTime _dayKey(int dayNumber) => DateTime(1970, 1, dayNumber);

  Future<void> setHotelForDay({
    required String tripId,
    required String spotId,
    required int dayNumber,
  }) async {
    final key = _dayKey(dayNumber);
    // Remove existing hotel for this day
    await (_db.delete(_db.hotelStays)
          ..where((t) =>
              t.tripId.equals(tripId) &
              t.checkInDateTime.equals(key)))
        .go();
    await _db.into(_db.hotelStays).insert(
          HotelStaysCompanion.insert(
            tripId: tripId,
            spotId: spotId,
            checkInDateTime: key,
            checkOutDateTime: _dayKey(dayNumber + 1),
          ),
        );
  }

  Future<void> removeHotelForDay(String tripId, int dayNumber) {
    return (_db.delete(_db.hotelStays)
          ..where((t) =>
              t.tripId.equals(tripId) &
              t.checkInDateTime.equals(_dayKey(dayNumber))))
        .go();
  }

  Stream<HotelStay?> watchHotelForDay(String tripId, int dayNumber) {
    final key = _dayKey(dayNumber);
    return (_db.select(_db.hotelStays)
          ..where((t) =>
              t.tripId.equals(tripId) &
              t.checkInDateTime.equals(key)))
        .watchSingleOrNull();
  }

  Future<void> deleteDays(String tripId) async {
    final days = await (_db.select(_db.itineraryDays)
          ..where((t) => t.tripId.equals(tripId)))
        .get();
    for (final day in days) {
      await (_db.delete(_db.dayItems)..where((t) => t.dayId.equals(day.id)))
          .go();
    }
    await (_db.delete(_db.itineraryDays)
          ..where((t) => t.tripId.equals(tripId)))
        .go();
  }
}
