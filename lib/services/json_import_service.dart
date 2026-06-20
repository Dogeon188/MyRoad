import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';
import 'package:uuid/uuid.dart';

class JsonImportService {
  final AppDatabase _db;
  static const _uuid = Uuid();

  JsonImportService(this._db);

  Future<String> importRegion(Map<String, dynamic> json) async {
    if (json['schemaVersion'] != 1) throw const FormatException('Unknown schema version');
    if (json['type'] != 'region') throw const FormatException('Expected type region');
    final (regionId, _) = await _importRegionData(json['data'] as Map<String, dynamic>);
    return regionId;
  }

  Future<String> importTrip(Map<String, dynamic> json) async {
    if (json['schemaVersion'] != 1) throw const FormatException('Unknown schema version');
    if (json['type'] != 'trip') throw const FormatException('Expected type trip');

    final data = json['data'] as Map<String, dynamic>;
    final tripId = _uuid.v4();

    await _db.into(_db.trips).insert(TripsCompanion.insert(
      id: Value(tripId),
      name: data['name'] as String,
      transportPreference: Value(data['transportPreference'] as String? ?? 'walk'),
      planMode: Value(data['planMode'] as String? ?? 'coarse'),
      startDate: Value(data['startDate'] != null ? DateTime.parse(data['startDate'] as String) : null),
      endDate: Value(data['endDate'] != null ? DateTime.parse(data['endDate'] as String) : null),
    ));

    final idMap = <String, String>{};
    final regionsData = data['regions'] as List? ?? [];
    for (final regionEntry in regionsData) {
      final regionData = regionEntry['region'] as Map<String, dynamic>;
      final order = regionEntry['order'] as int? ?? 0;
      final (regionId, regionIdMap) = await _importRegionData(regionData);
      idMap.addAll(regionIdMap);

      await _db.into(_db.tripRegions).insert(TripRegionsCompanion.insert(
        tripId: tripId,
        regionId: regionId,
        order: Value(order),
      ));
    }

    final itinerary = data['itinerary'] as List?;
    if (itinerary != null) {
      for (final dayJson in itinerary) {
        final day = await _db.into(_db.itineraryDays).insertReturning(
          ItineraryDaysCompanion.insert(
            tripId: tripId,
            dayNumber: dayJson['dayNumber'] as int,
            date: Value(dayJson['date'] != null ? DateTime.parse(dayJson['date'] as String) : null),
          ),
        );
        for (final itemJson in dayJson['items'] as List) {
          final oldAreaId = itemJson['areaId'] as String?;
          final oldSpotId = itemJson['spotId'] as String?;
          await _db.into(_db.dayItems).insert(DayItemsCompanion.insert(
            dayId: day.id,
            areaId: Value(oldAreaId != null ? idMap[oldAreaId] ?? oldAreaId : null),
            spotId: Value(oldSpotId != null ? idMap[oldSpotId] ?? oldSpotId : null),
            itemType: Value(itemJson['itemType'] as String? ?? 'area'),
            order: itemJson['order'] as int,
            startTimeMinutes: Value(itemJson['startTimeMinutes'] as int?),
            endTimeMinutes: Value(itemJson['endTimeMinutes'] as int?),
          ));
        }
      }
    }

    final hotelStays = data['hotelStays'] as List?;
    if (hotelStays != null) {
      for (final h in hotelStays) {
        final oldSpotId = h['spotId'] as String;
        await _db.into(_db.hotelStays).insert(HotelStaysCompanion.insert(
          tripId: tripId,
          spotId: idMap[oldSpotId] ?? oldSpotId,
          checkInDateTime: DateTime.parse(h['checkIn'] as String),
          checkOutDateTime: DateTime.parse(h['checkOut'] as String),
        ));
      }
    }

    return tripId;
  }

  Future<(String, Map<String, String>)> _importRegionData(Map<String, dynamic> data) async {
    final idMap = <String, String>{};
    final oldRegionId = data['id'] as String?;

    // Reuse existing region if it exists
    if (oldRegionId != null) {
      final existing = await (_db.select(_db.regions)..where((t) => t.id.equals(oldRegionId))).getSingleOrNull();
      if (existing != null) {
        // Region exists — areas/spots likely exist too, build identity map
        await _buildExistingIdMap(oldRegionId, data, idMap);
        return (oldRegionId, idMap);
      }
    }

    final regionId = oldRegionId ?? _uuid.v4();
    await _db.into(_db.regions).insert(RegionsCompanion.insert(
      id: Value(regionId),
      name: data['name'] as String,
      description: Value(data['description'] as String?),
    ));

    for (final areaJson in (data['areas'] as List? ?? [])) {
      await _importArea(areaJson, regionId: regionId, idMap: idMap);
    }

    return (regionId, idMap);
  }

  Future<void> _importArea(Map<String, dynamic> areaJson, {required String regionId, required Map<String, String> idMap}) async {
    final oldAreaId = areaJson['id'] as String?;

    // Reuse existing area
    if (oldAreaId != null) {
      final existing = await (_db.select(_db.areas)..where((t) => t.id.equals(oldAreaId))).getSingleOrNull();
      if (existing != null) {
        idMap[oldAreaId] = oldAreaId;
        for (final spotJson in (areaJson['spots'] as List? ?? [])) {
          final oldSpotId = spotJson['id'] as String?;
          if (oldSpotId != null) idMap[oldSpotId] = oldSpotId;
        }
        return;
      }
    }

    final areaId = oldAreaId ?? _uuid.v4();
    idMap[oldAreaId ?? areaId] = areaId;

    await _db.into(_db.areas).insert(AreasCompanion.insert(
      id: Value(areaId),
      name: areaJson['name'] as String,
      regionId: regionId,
      type: Value(areaJson['type'] as String? ?? 'city'),
      order: Value(areaJson['order'] as int? ?? 0),
      estimatedDurationMinutes: Value(areaJson['estimatedDurationMinutes'] as int? ?? 480),
    ));

    for (final spotJson in (areaJson['spots'] as List? ?? [])) {
      await _importSpot(spotJson, areaId: areaId, idMap: idMap);
    }
  }

  Future<void> _importSpot(Map<String, dynamic> spotJson, {required String areaId, required Map<String, String> idMap}) async {
    final oldSpotId = spotJson['id'] as String?;

    if (oldSpotId != null) {
      final existing = await (_db.select(_db.spots)..where((t) => t.id.equals(oldSpotId))).getSingleOrNull();
      if (existing != null) {
        idMap[oldSpotId] = oldSpotId;
        return;
      }
    }

    final spotId = oldSpotId ?? _uuid.v4();
    idMap[oldSpotId ?? spotId] = spotId;

    await _db.into(_db.spots).insert(SpotsCompanion.insert(
      id: Value(spotId),
      areaId: areaId,
      name: spotJson['name'] as String,
      type: Value(spotJson['type'] as String? ?? 'spot'),
      lat: Value((spotJson['lat'] as num?)?.toDouble()),
      lng: Value((spotJson['lng'] as num?)?.toDouble()),
      address: Value(spotJson['address'] as String? ?? ''),
      googlePlaceId: Value(spotJson['googlePlaceId'] as String?),
      previewImageUrl: Value(spotJson['previewImageUrl'] as String?),
      notes: Value(spotJson['notes'] as String? ?? ''),
      estimatedVisitDurationMinutes: Value(spotJson['estimatedVisitDurationMinutes'] as int? ?? 60),
      bufferTimeMinutes: Value(spotJson['bufferTimeMinutes'] as int? ?? 15),
      review: Value(spotJson['review'] as String?),
    ));

    for (final ci in (spotJson['customInfo'] as List? ?? [])) {
      await _db.into(_db.spotCustomInfos).insert(
        SpotCustomInfosCompanion.insert(
          spotId: spotId,
          label: ci['label'] as String,
          value: ci['value'] as String,
        ),
      );
    }
    for (final oh in (spotJson['openingHours'] as List? ?? [])) {
      await _db.into(_db.spotOpeningHoursEntries).insert(
        SpotOpeningHoursEntriesCompanion.insert(
          spotId: spotId,
          day: oh['day'] as int,
          openMinutes: oh['open'] as int,
          closeMinutes: oh['close'] as int,
        ),
      );
    }
  }

  /// When a region already exists, build identity mappings from the JSON so itinerary refs resolve.
  Future<void> _buildExistingIdMap(String regionId, Map<String, dynamic> data, Map<String, String> idMap) async {
    for (final areaJson in (data['areas'] as List? ?? [])) {
      final oldAreaId = areaJson['id'] as String?;
      if (oldAreaId != null) idMap[oldAreaId] = oldAreaId;
      for (final spotJson in (areaJson['spots'] as List? ?? [])) {
        final oldSpotId = spotJson['id'] as String?;
        if (oldSpotId != null) idMap[oldSpotId] = oldSpotId;
      }
    }
  }
}
