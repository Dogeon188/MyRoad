import 'package:drift/drift.dart';
import 'package:myroad/database/database.dart';

class JsonExportService {
  final AppDatabase _db;

  JsonExportService(this._db);

  Future<Map<String, dynamic>> exportRegion(String regionId) async {
    final region = await (_db.select(
      _db.regions,
    )..where((t) => t.id.equals(regionId))).getSingle();
    final areas =
        await (_db.select(_db.areas)
              ..where((t) => t.regionId.equals(regionId))
              ..orderBy([(t) => OrderingTerm.asc(t.order)]))
            .get();

    final areasJson = <Map<String, dynamic>>[];
    for (final area in areas) {
      final spots =
          await (_db.select(_db.spots)
                ..where((t) => t.areaId.equals(area.id))
                ..orderBy([(t) => OrderingTerm.asc(t.order)]))
              .get();
      final spotsJson = <Map<String, dynamic>>[];

      for (final spot in spots) {
        final customInfos = await (_db.select(
          _db.spotCustomInfos,
        )..where((t) => t.spotId.equals(spot.id))).get();
        final hours = await (_db.select(
          _db.spotOpeningHoursEntries,
        )..where((t) => t.spotId.equals(spot.id))).get();

        spotsJson.add({
          'id': spot.id,
          'name': spot.name,
          'type': spot.type,
          'lat': spot.lat,
          'lng': spot.lng,
          'address': spot.address,
          'googlePlaceId': spot.googlePlaceId,
          'previewImageUrl': spot.previewImageUrl,
          'order': spot.order,
          'notes': spot.notes,
          'estimatedVisitDurationMinutes': spot.estimatedVisitDurationMinutes,
          'bufferTimeMinutes': spot.bufferTimeMinutes,
          'review': spot.review,
          'rating': spot.rating,
          'price': spot.price,
          'iconCode': spot.iconCode,
          'colorValue': spot.colorValue,
          'url': spot.url,
          'customInfo': customInfos
              .map((i) => {'label': i.label, 'value': i.value})
              .toList(),
          'openingHours': hours
              .map(
                (h) => {
                  'day': h.day,
                  'open': h.openMinutes,
                  'close': h.closeMinutes,
                },
              )
              .toList(),
        });
      }

      areasJson.add({
        'id': area.id,
        'name': area.name,
        'type': area.type,
        'order': area.order,
        'estimatedDurationMinutes': area.estimatedDurationMinutes,
        'boundsSouth': area.boundsSouth,
        'boundsWest': area.boundsWest,
        'boundsNorth': area.boundsNorth,
        'boundsEast': area.boundsEast,
        'review': area.review,
        'rating': area.rating,
        'spots': spotsJson,
      });
    }

    return {
      'schemaVersion': 1,
      'type': 'region',
      'data': {
        'id': region.id,
        'name': region.name,
        'description': region.description,
        'review': region.review,
        'rating': region.rating,
        'currency': region.currency,
        'areas': areasJson,
      },
    };
  }

  Future<Map<String, dynamic>> exportTrip(String tripId) async {
    final trip = await (_db.select(
      _db.trips,
    )..where((t) => t.id.equals(tripId))).getSingle();

    final tripRegions =
        await (_db.select(_db.tripRegions)
              ..where((t) => t.tripId.equals(tripId))
              ..orderBy([(t) => OrderingTerm.asc(t.order)]))
            .get();

    final regionsJson = <Map<String, dynamic>>[];
    for (final tr in tripRegions) {
      final regionExport = await exportRegion(tr.regionId);
      regionsJson.add({'order': tr.order, 'region': regionExport['data']});
    }

    final days =
        await (_db.select(_db.itineraryDays)
              ..where((t) => t.tripId.equals(tripId))
              ..orderBy([(t) => OrderingTerm.asc(t.dayNumber)]))
            .get();
    final daysJson = await Future.wait(
      days.map((day) async {
        final items =
            await (_db.select(_db.dayItems)
                  ..where((t) => t.dayId.equals(day.id))
                  ..orderBy([(t) => OrderingTerm.asc(t.order)]))
                .get();
        return {
          'dayNumber': day.dayNumber,
          'date': day.date?.toIso8601String(),
          'departureTimeMinutes': day.departureTimeMinutes,
          'arrivalTimeMinutes': day.arrivalTimeMinutes,
          'items': items
              .map(
                (i) => {
                  'areaId': i.areaId,
                  'spotId': i.spotId,
                  'itemType': i.itemType,
                  'order': i.order,
                  'startTimeMinutes': i.startTimeMinutes,
                  'endTimeMinutes': i.endTimeMinutes,
                  'transportToNextId': i.transportToNextId,
                  'passId': i.passId,
                },
              )
              .toList(),
        };
      }),
    );

    final hotelStays = await (_db.select(
      _db.hotelStays,
    )..where((t) => t.tripId.equals(tripId))).get();

    final transports = await (_db.select(
      _db.transports,
    )..where((t) => t.tripId.equals(tripId))).get();

    final spotTimes = await (_db.select(
      _db.tripSpotTimes,
    )..where((t) => t.tripId.equals(tripId))).get();

    final travelPasses = await (_db.select(
      _db.travelPasses,
    )..where((t) => t.tripId.equals(tripId))).get();

    return {
      'schemaVersion': 2,
      'type': 'trip',
      'data': {
        'name': trip.name,
        'transportPreference': trip.transportPreference,
        'bufferTimeDefaultMinutes': trip.bufferTimeDefaultMinutes,
        'planMode': trip.planMode,
        'startDate': trip.startDate?.toIso8601String(),
        'endDate': trip.endDate?.toIso8601String(),
        'regions': regionsJson,
        'itinerary': daysJson,
        'travelPasses': travelPasses
            .map(
              (p) => {
                'id': p.id,
                'name': p.name,
                'url': p.url,
                'price': p.price,
                'startDay': p.startDay,
                'endDay': p.endDay,
                'bought': p.bought,
                'note': p.note,
              },
            )
            .toList(),
        'hotelStays': hotelStays
            .map(
              (h) => {
                'spotId': h.spotId,
                'checkIn': h.checkInDateTime.toIso8601String(),
                'checkOut': h.checkOutDateTime.toIso8601String(),
              },
            )
            .toList(),
        'transports': transports
            .map(
              (t) => {
                'id': t.id,
                'fromSpotId': t.fromSpotId,
                'toSpotId': t.toSpotId,
                'mode': t.mode,
                'estimatedDurationMinutes': t.estimatedDurationMinutes,
                'distanceMeters': t.distanceMeters,
                'routePolyline': t.routePolyline,
                'routeName': t.routeName,
                'price': t.price,
                'notes': t.notes,
                'passId': t.passId,
              },
            )
            .toList(),
        'spotTimes': spotTimes
            .map(
              (st) => {
                'spotId': st.spotId,
                'startTimeMinutes': st.startTimeMinutes,
                'afterTransport': st.afterTransport,
                'skipped': st.skipped,
              },
            )
            .toList(),
      },
    };
  }
}
