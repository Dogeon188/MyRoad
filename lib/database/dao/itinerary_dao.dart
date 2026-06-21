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
    await _syncTripEndDate(tripId, dayCount);
  }

  Future<String> addAreaToDay({
    required String dayId,
    required String areaId,
    required int order,
  }) async {
    final item = await _db.into(_db.dayItems).insertReturning(
          DayItemsCompanion.insert(
            dayId: dayId,
            areaId: Value(areaId),
            order: order,
          ),
        );
    return item.id;
  }

  Future<String> addHotelItem({
    required String dayId,
    required String itemType,
    required int order,
  }) async {
    final item = await _db.into(_db.dayItems).insertReturning(
          DayItemsCompanion.insert(
            dayId: dayId,
            itemType: Value(itemType),
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

  Future<void> reorderItems(List<String> ids) async {
    await _db.batch((batch) {
      for (var i = 0; i < ids.length; i++) {
        batch.update(
          _db.dayItems,
          DayItemsCompanion(order: Value(i)),
          where: ($DayItemsTable t) => t.id.equals(ids[i]),
        );
      }
    });
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

  // ponytail: day numbers encoded as DateTime(1970,1,dayNumber), real dates when trip has them
  static DateTime _dayKey(int dayNumber) => DateTime(1970, 1, dayNumber);
  static int dayFromKey(DateTime dt) => dt.day;

  Future<String> addHotelStayForDays({
    required String tripId,
    required String spotId,
    required int checkInDay,
    required int checkOutDay,
  }) async {
    final stay = await _db.into(_db.hotelStays).insertReturning(
          HotelStaysCompanion.insert(
            tripId: tripId,
            spotId: spotId,
            checkInDateTime: _dayKey(checkInDay),
            checkOutDateTime: _dayKey(checkOutDay),
          ),
        );
    return stay.id;
  }

  Future<void> updateHotelStay(String id,
      {String? spotId, int? checkInDay, int? checkOutDay}) {
    return (_db.update(_db.hotelStays)..where((t) => t.id.equals(id))).write(
      HotelStaysCompanion(
        spotId: spotId != null ? Value(spotId) : const Value.absent(),
        checkInDateTime:
            checkInDay != null ? Value(_dayKey(checkInDay)) : const Value.absent(),
        checkOutDateTime:
            checkOutDay != null ? Value(_dayKey(checkOutDay)) : const Value.absent(),
      ),
    );
  }

  /// Which hotel stay covers this day? A stay covers [checkInDay, checkOutDay).
  static HotelStay? hotelForDay(List<HotelStay> stays, int dayNumber) {
    for (final stay in stays) {
      final checkIn = dayFromKey(stay.checkInDateTime);
      final checkOut = dayFromKey(stay.checkOutDateTime);
      if (dayNumber >= checkIn && dayNumber < checkOut) return stay;
    }
    return null;
  }

  Stream<Map<String, int>> watchSpotTimes(String tripId) {
    return (_db.select(_db.tripSpotTimes)
          ..where((t) => t.tripId.equals(tripId)))
        .watch()
        .map((rows) => {
          for (final r in rows)
            if (r.startTimeMinutes != null) r.spotId: r.startTimeMinutes!,
        });
  }

  Stream<Set<String>> watchAfterTransportSpots(String tripId) {
    return (_db.select(_db.tripSpotTimes)
          ..where((t) => t.tripId.equals(tripId) & t.afterTransport.equals(true)))
        .watch()
        .map((rows) => rows.map((r) => r.spotId).toSet());
  }

  Stream<Set<String>> watchSkippedSpots(String tripId) {
    return (_db.select(_db.tripSpotTimes)
          ..where((t) => t.tripId.equals(tripId) & t.skipped.equals(true)))
        .watch()
        .map((rows) => rows.map((r) => r.spotId).toSet());
  }

  Future<void> toggleSkipped(String tripId, String spotId) async {
    final existing = await (_db.select(_db.tripSpotTimes)
          ..where((t) => t.tripId.equals(tripId) & t.spotId.equals(spotId)))
        .getSingleOrNull();
    if (existing != null) {
      final newVal = !existing.skipped;
      if (!newVal && existing.startTimeMinutes == null && !existing.afterTransport) {
        await (_db.delete(_db.tripSpotTimes)
              ..where((t) => t.tripId.equals(tripId) & t.spotId.equals(spotId)))
            .go();
      } else {
        await (_db.update(_db.tripSpotTimes)
              ..where((t) => t.tripId.equals(tripId) & t.spotId.equals(spotId)))
            .write(TripSpotTimesCompanion(skipped: Value(newVal)));
      }
    } else {
      await _db.into(_db.tripSpotTimes).insert(
            TripSpotTimesCompanion.insert(
              tripId: tripId,
              spotId: spotId,
              skipped: const Value(true),
            ),
          );
    }
  }

  Future<void> setSpotTime(String tripId, String spotId, int? startMinutes) async {
    if (startMinutes == null) {
      final existing = await (_db.select(_db.tripSpotTimes)
            ..where((t) => t.tripId.equals(tripId) & t.spotId.equals(spotId)))
          .getSingleOrNull();
      if (existing != null && existing.afterTransport) {
        await (_db.update(_db.tripSpotTimes)
              ..where((t) => t.tripId.equals(tripId) & t.spotId.equals(spotId)))
            .write(const TripSpotTimesCompanion(startTimeMinutes: Value(null)));
      } else {
        await (_db.delete(_db.tripSpotTimes)
              ..where((t) => t.tripId.equals(tripId) & t.spotId.equals(spotId)))
            .go();
      }
      return;
    }
    await _db.into(_db.tripSpotTimes).insertOnConflictUpdate(
          TripSpotTimesCompanion.insert(
            tripId: tripId,
            spotId: spotId,
            startTimeMinutes: Value(startMinutes),
          ),
        );
  }

  Future<void> toggleAfterTransport(String tripId, String spotId) async {
    final existing = await (_db.select(_db.tripSpotTimes)
          ..where((t) => t.tripId.equals(tripId) & t.spotId.equals(spotId)))
        .getSingleOrNull();
    if (existing != null) {
      final newVal = !existing.afterTransport;
      if (!newVal && existing.startTimeMinutes == null) {
        // No time and toggling off — delete the row
        await (_db.delete(_db.tripSpotTimes)
              ..where((t) => t.tripId.equals(tripId) & t.spotId.equals(spotId)))
            .go();
      } else {
        await (_db.update(_db.tripSpotTimes)
              ..where((t) => t.tripId.equals(tripId) & t.spotId.equals(spotId)))
            .write(TripSpotTimesCompanion(afterTransport: Value(newVal)));
      }
    } else {
      await _db.into(_db.tripSpotTimes).insert(
            TripSpotTimesCompanion.insert(
              tripId: tripId,
              spotId: spotId,
              afterTransport: const Value(true),
            ),
          );
    }
  }

  Future<void> setDayDepartureTime(String dayId, int? minutes) {
    return (_db.update(_db.itineraryDays)..where((t) => t.id.equals(dayId)))
        .write(ItineraryDaysCompanion(departureTimeMinutes: Value(minutes)));
  }

  Future<void> setDayArrivalTime(String dayId, int? minutes) {
    return (_db.update(_db.itineraryDays)..where((t) => t.id.equals(dayId)))
        .write(ItineraryDaysCompanion(arrivalTimeMinutes: Value(minutes)));
  }

  Future<void> setTransportToNext(String itemId, String? transportId) {
    return (_db.update(_db.dayItems)..where((t) => t.id.equals(itemId))).write(
      DayItemsCompanion(transportToNextId: Value(transportId)),
    );
  }

  Future<void> _syncTripEndDate(String tripId, int dayCount) async {
    final trip = await (_db.select(_db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip?.startDate == null) return;
    final newEnd = trip!.startDate!.add(Duration(days: dayCount - 1));
    await (_db.update(_db.trips)..where((t) => t.id.equals(tripId)))
        .write(TripsCompanion(endDate: Value(newEnd)));
  }

  Future<void> addDay(String tripId, int dayNumber) async {
    await _db.into(_db.itineraryDays).insert(
      ItineraryDaysCompanion.insert(tripId: tripId, dayNumber: dayNumber),
    );
    await _syncTripEndDate(tripId, dayNumber);
  }

  Future<void> deleteDayAndRenumber(String tripId, String dayId) async {
    await (_db.delete(_db.dayItems)..where((t) => t.dayId.equals(dayId))).go();
    await (_db.delete(_db.itineraryDays)..where((t) => t.id.equals(dayId))).go();
    // Renumber remaining days
    final remaining = await (_db.select(_db.itineraryDays)
          ..where((t) => t.tripId.equals(tripId))
          ..orderBy([(t) => OrderingTerm.asc(t.dayNumber)]))
        .get();
    for (var i = 0; i < remaining.length; i++) {
      if (remaining[i].dayNumber != i + 1) {
        await (_db.update(_db.itineraryDays)
              ..where((t) => t.id.equals(remaining[i].id)))
            .write(ItineraryDaysCompanion(dayNumber: Value(i + 1)));
      }
    }
    await _syncTripEndDate(tripId, remaining.length);
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
