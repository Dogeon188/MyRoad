import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';
import 'package:uuid/uuid.dart';

class JsonImportService {
  final AppDatabase _db;
  static const _uuid = Uuid();

  JsonImportService(this._db);

  Future<String> importRegion(Map<String, dynamic> json) async {
    final version = json['schemaVersion'] as int;
    if (version < 1 || version > 2) {
      throw const FormatException('Unknown schema version');
    }
    if (json['type'] != 'region') {
      throw const FormatException('Expected type region');
    }
    final (regionId, _) = await _importRegionData(
      json['data'] as Map<String, dynamic>,
    );
    return regionId;
  }

  Future<String> importTrip(Map<String, dynamic> json) async {
    final version = json['schemaVersion'] as int;
    if (version < 1 || version > 2) {
      throw const FormatException('Unknown schema version');
    }
    if (json['type'] != 'trip') {
      throw const FormatException('Expected type trip');
    }

    final data = json['data'] as Map<String, dynamic>;
    final tripId = _uuid.v4();

    await _db
        .into(_db.trips)
        .insert(
          TripsCompanion.insert(
            id: Value(tripId),
            name: data['name'] as String,
            transportPreference: Value(
              data['transportPreference'] as String? ?? 'walk',
            ),
            bufferTimeDefaultMinutes: Value(
              data['bufferTimeDefaultMinutes'] as int? ?? 15,
            ),
            planMode: Value(data['planMode'] as String? ?? 'coarse'),
            startDate: Value(
              data['startDate'] != null
                  ? DateTime.parse(data['startDate'] as String)
                  : null,
            ),
            endDate: Value(
              data['endDate'] != null
                  ? DateTime.parse(data['endDate'] as String)
                  : null,
            ),
          ),
        );

    final idMap = <String, String>{};
    final regionsData = data['regions'] as List? ?? [];
    for (final regionEntry in regionsData) {
      final regionData = regionEntry['region'] as Map<String, dynamic>;
      final order = regionEntry['order'] as int? ?? 0;
      final (regionId, regionIdMap) = await _importRegionData(regionData);
      idMap.addAll(regionIdMap);

      await _db
          .into(_db.tripRegions)
          .insert(
            TripRegionsCompanion.insert(
              tripId: tripId,
              regionId: regionId,
              order: Value(order),
            ),
          );
    }

    final passIdMap = <String, String>{};
    final travelPasses = data['travelPasses'] as List?;
    if (travelPasses != null) {
      for (final p in travelPasses) {
        final newId = _uuid.v4();
        passIdMap[p['id'] as String] = newId;
        await _db
            .into(_db.travelPasses)
            .insert(
              TravelPassesCompanion.insert(
                id: Value(newId),
                tripId: tripId,
                name: p['name'] as String,
                url: Value(p['url'] as String?),
                price: Value(p['price'] as String?),
                startDay: Value(p['startDay'] as int? ?? 1),
                endDay: Value(p['endDay'] as int? ?? 1),
                bought: Value(p['bought'] as bool? ?? false),
                note: Value(p['note'] as String?),
              ),
            );
      }
    }

    final itinerary = data['itinerary'] as List?;
    if (itinerary != null) {
      for (final dayJson in itinerary) {
        final day = await _db
            .into(_db.itineraryDays)
            .insertReturning(
              ItineraryDaysCompanion.insert(
                tripId: tripId,
                dayNumber: dayJson['dayNumber'] as int,
                date: Value(
                  dayJson['date'] != null
                      ? DateTime.parse(dayJson['date'] as String)
                      : null,
                ),
                departureTimeMinutes: Value(
                  dayJson['departureTimeMinutes'] as int?,
                ),
                arrivalTimeMinutes: Value(
                  dayJson['arrivalTimeMinutes'] as int?,
                ),
              ),
            );
        for (final itemJson in dayJson['items'] as List) {
          final oldAreaId = itemJson['areaId'] as String?;
          final oldSpotId = itemJson['spotId'] as String?;
          await _db
              .into(_db.dayItems)
              .insert(
                DayItemsCompanion.insert(
                  dayId: day.id,
                  areaId: Value(
                    oldAreaId != null ? idMap[oldAreaId] ?? oldAreaId : null,
                  ),
                  spotId: Value(
                    oldSpotId != null ? idMap[oldSpotId] ?? oldSpotId : null,
                  ),
                  itemType: Value(itemJson['itemType'] as String? ?? 'area'),
                  order: itemJson['order'] as int,
                  startTimeMinutes: Value(itemJson['startTimeMinutes'] as int?),
                  endTimeMinutes: Value(itemJson['endTimeMinutes'] as int?),
                  // transportToNextId stored as old ID, patched after transports are imported
                  transportToNextId: Value(
                    itemJson['transportToNextId'] as String?,
                  ),
                  passId: Value(passIdMap[itemJson['passId']]),
                ),
              );
        }
      }
    }

    final hotelStays = data['hotelStays'] as List?;
    if (hotelStays != null) {
      for (final h in hotelStays) {
        final oldSpotId = h['spotId'] as String;
        await _db
            .into(_db.hotelStays)
            .insert(
              HotelStaysCompanion.insert(
                tripId: tripId,
                spotId: idMap[oldSpotId] ?? oldSpotId,
                checkInDateTime: DateTime.parse(h['checkIn'] as String),
                checkOutDateTime: DateTime.parse(h['checkOut'] as String),
              ),
            );
      }
    }

    final transportIdMap = <String, String>{};
    final transports = data['transports'] as List?;
    if (transports != null) {
      for (final t in transports) {
        final oldId = t['id'] as String;
        final newId = _uuid.v4();
        transportIdMap[oldId] = newId;
        final oldFrom = t['fromSpotId'] as String;
        final oldTo = t['toSpotId'] as String;
        await _db
            .into(_db.transports)
            .insert(
              TransportsCompanion.insert(
                id: Value(newId),
                tripId: tripId,
                fromSpotId: idMap[oldFrom] ?? oldFrom,
                toSpotId: idMap[oldTo] ?? oldTo,
                mode: Value(t['mode'] as String? ?? 'walk'),
                estimatedDurationMinutes: t['estimatedDurationMinutes'] as int,
                distanceMeters: Value(
                  (t['distanceMeters'] as num?)?.toDouble(),
                ),
                routePolyline: Value(t['routePolyline'] as String?),
                routeName: Value(t['routeName'] as String?),
                price: Value(t['price'] as String?),
                notes: Value(t['notes'] as String?),
                passId: Value(passIdMap[t['passId']]),
              ),
            );
      }
    }

    // Patch transportToNextId references on day items
    if (transportIdMap.isNotEmpty) {
      final allDays = await (_db.select(
        _db.itineraryDays,
      )..where((t) => t.tripId.equals(tripId))).get();
      for (final day in allDays) {
        final items = await (_db.select(
          _db.dayItems,
        )..where((t) => t.dayId.equals(day.id))).get();
        for (final item in items) {
          if (item.transportToNextId != null) {
            final newTid = transportIdMap[item.transportToNextId];
            if (newTid != null) {
              await (_db.update(_db.dayItems)
                    ..where((t) => t.id.equals(item.id)))
                  .write(DayItemsCompanion(transportToNextId: Value(newTid)));
            }
          }
        }
      }
    }

    final spotTimesJson = data['spotTimes'] as List?;
    if (spotTimesJson != null) {
      for (final st in spotTimesJson) {
        final oldSpotId = st['spotId'] as String;
        await _db
            .into(_db.tripSpotTimes)
            .insert(
              TripSpotTimesCompanion.insert(
                tripId: tripId,
                spotId: idMap[oldSpotId] ?? oldSpotId,
                startTimeMinutes: Value(st['startTimeMinutes'] as int?),
                afterTransport: Value(st['afterTransport'] as bool? ?? false),
                skipped: Value(st['skipped'] as bool? ?? false),
              ),
            );
      }
    }

    return tripId;
  }

  Future<(String, Map<String, String>)> _importRegionData(
    Map<String, dynamic> data,
  ) async {
    final idMap = <String, String>{};
    final oldRegionId = data['id'] as String?;

    // Reuse existing region if it exists
    if (oldRegionId != null) {
      final existing = await (_db.select(
        _db.regions,
      )..where((t) => t.id.equals(oldRegionId))).getSingleOrNull();
      if (existing != null) {
        // Region exists — merge in any areas/spots from the JSON that aren't in it yet
        for (final areaJson in (data['areas'] as List? ?? [])) {
          await _importArea(areaJson, regionId: oldRegionId, idMap: idMap);
        }
        return (oldRegionId, idMap);
      }
    }

    final regionId = oldRegionId ?? _uuid.v4();
    await _db
        .into(_db.regions)
        .insert(
          RegionsCompanion.insert(
            id: Value(regionId),
            name: data['name'] as String,
            description: Value(data['description'] as String?),
            review: Value(data['review'] as String?),
            rating: Value(data['rating'] as int?),
            currency: Value(data['currency'] as String? ?? 'JPY'),
          ),
        );

    for (final areaJson in (data['areas'] as List? ?? [])) {
      await _importArea(areaJson, regionId: regionId, idMap: idMap);
    }

    return (regionId, idMap);
  }

  Future<void> _importArea(
    Map<String, dynamic> areaJson, {
    required String regionId,
    required Map<String, String> idMap,
  }) async {
    final oldAreaId = areaJson['id'] as String?;

    // Reuse existing area
    if (oldAreaId != null) {
      final existing = await (_db.select(
        _db.areas,
      )..where((t) => t.id.equals(oldAreaId))).getSingleOrNull();
      if (existing != null) {
        idMap[oldAreaId] = oldAreaId;
        // Area exists — merge in any spots from the JSON that aren't in it yet
        for (final spotJson in (areaJson['spots'] as List? ?? [])) {
          await _importSpot(spotJson, areaId: oldAreaId, idMap: idMap);
        }
        return;
      }
    }

    final areaId = oldAreaId ?? _uuid.v4();
    idMap[oldAreaId ?? areaId] = areaId;

    await _db
        .into(_db.areas)
        .insert(
          AreasCompanion.insert(
            id: Value(areaId),
            name: areaJson['name'] as String,
            regionId: regionId,
            type: Value(areaJson['type'] as String? ?? 'city'),
            order: Value(areaJson['order'] as int? ?? 0),
            estimatedDurationMinutes: Value(
              areaJson['estimatedDurationMinutes'] as int? ?? 480,
            ),
            boundsSouth: Value((areaJson['boundsSouth'] as num?)?.toDouble()),
            boundsWest: Value((areaJson['boundsWest'] as num?)?.toDouble()),
            boundsNorth: Value((areaJson['boundsNorth'] as num?)?.toDouble()),
            boundsEast: Value((areaJson['boundsEast'] as num?)?.toDouble()),
            review: Value(areaJson['review'] as String?),
            rating: Value(areaJson['rating'] as int?),
          ),
        );

    for (final spotJson in (areaJson['spots'] as List? ?? [])) {
      await _importSpot(spotJson, areaId: areaId, idMap: idMap);
    }
  }

  Future<void> _importSpot(
    Map<String, dynamic> spotJson, {
    required String areaId,
    required Map<String, String> idMap,
  }) async {
    final oldSpotId = spotJson['id'] as String?;

    if (oldSpotId != null) {
      final existing = await (_db.select(
        _db.spots,
      )..where((t) => t.id.equals(oldSpotId))).getSingleOrNull();
      if (existing != null) {
        idMap[oldSpotId] = oldSpotId;
        return;
      }
    }

    final spotId = oldSpotId ?? _uuid.v4();
    idMap[oldSpotId ?? spotId] = spotId;

    await _db
        .into(_db.spots)
        .insert(
          SpotsCompanion.insert(
            id: Value(spotId),
            areaId: areaId,
            name: spotJson['name'] as String,
            type: Value(spotJson['type'] as String? ?? 'spot'),
            lat: Value((spotJson['lat'] as num?)?.toDouble()),
            lng: Value((spotJson['lng'] as num?)?.toDouble()),
            address: Value(spotJson['address'] as String? ?? ''),
            googlePlaceId: Value(spotJson['googlePlaceId'] as String?),
            previewImageUrl: Value(spotJson['previewImageUrl'] as String?),
            order: Value(spotJson['order'] as int?),
            notes: Value(spotJson['notes'] as String? ?? ''),
            estimatedVisitDurationMinutes: Value(
              spotJson['estimatedVisitDurationMinutes'] as int? ?? 60,
            ),
            bufferTimeMinutes: Value(
              spotJson['bufferTimeMinutes'] as int? ?? 15,
            ),
            review: Value(spotJson['review'] as String?),
            rating: Value(spotJson['rating'] as int?),
            price: Value(spotJson['price'] as String?),
            iconCode: Value(spotJson['iconCode'] as int?),
            colorValue: Value(spotJson['colorValue'] as int?),
            url: Value(spotJson['url'] as String?),
          ),
        );

    for (final ci in (spotJson['customInfo'] as List? ?? [])) {
      await _db
          .into(_db.spotCustomInfos)
          .insert(
            SpotCustomInfosCompanion.insert(
              spotId: spotId,
              label: ci['label'] as String,
              value: ci['value'] as String,
            ),
          );
    }
    for (final oh in (spotJson['openingHours'] as List? ?? [])) {
      await _db
          .into(_db.spotOpeningHoursEntries)
          .insert(
            SpotOpeningHoursEntriesCompanion.insert(
              spotId: spotId,
              day: oh['day'] as int,
              openMinutes: oh['open'] as int,
              closeMinutes: oh['close'] as int,
            ),
          );
    }
  }
}
