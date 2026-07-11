import 'package:drift/drift.dart';
import 'package:myroad/api/directions_api_client.dart';
import 'package:myroad/database/database.dart';

// ponytail: formattedAddress from Places API ends with country name
bool addressInJapan(String address) =>
    address.startsWith('日本') || address.endsWith('Japan');

class TransportService {
  final AppDatabase _db;
  final DirectionsApiClient _directionsClient;

  TransportService(this._db, this._directionsClient);

  /// Fetch available route options without inserting anything.
  Future<List<RouteOption>> fetchRouteOptions({
    required String fromSpotId,
    required String toSpotId,
    required String mode,
    DateTime? departTime,
    DateTime? arrivalTime,
  }) async {
    final fromSpot = await (_db.select(
      _db.spots,
    )..where((t) => t.id.equals(fromSpotId))).getSingleOrNull();
    final toSpot = await (_db.select(
      _db.spots,
    )..where((t) => t.id.equals(toSpotId))).getSingleOrNull();
    if (fromSpot == null || toSpot == null) return [];
    if (fromSpot.lat == null ||
        fromSpot.lng == null ||
        toSpot.lat == null ||
        toSpot.lng == null) {
      return [];
    }

    // ponytail: Google Directions transit API unavailable in Japan
    if (mode == 'transit' &&
        (addressInJapan(fromSpot.address) || addressInJapan(toSpot.address))) {
      return [];
    }

    return _directionsClient.getRoutes(
      originLat: fromSpot.lat!,
      originLng: fromSpot.lng!,
      destLat: toSpot.lat!,
      destLng: toSpot.lng!,
      mode: mode,
      departTime: departTime,
      arrivalTime: arrivalTime,
    );
  }

  /// Apply a chosen route option: deletes existing legs, inserts new ones.
  Future<List<Transport>> applyRoute({
    required String fromSpotId,
    required String toSpotId,
    required String tripId,
    required RouteOption route,
  }) async {
    await (_db.delete(_db.transports)..where(
          (t) => t.fromSpotId.equals(fromSpotId) & t.toSpotId.equals(toSpotId),
        ))
        .go();

    final inserted = <Transport>[];
    for (final leg in route.legs) {
      final t = await _db
          .into(_db.transports)
          .insertReturning(
            TransportsCompanion.insert(
              tripId: tripId,
              fromSpotId: fromSpotId,
              toSpotId: toSpotId,
              mode: Value(leg.mode),
              estimatedDurationMinutes: leg.durationMinutes,
              distanceMeters: Value(leg.distanceMeters),
              routePolyline: Value(leg.polyline),
              routeName: Value(leg.routeName),
            ),
          );
      inserted.add(t);
    }
    return inserted;
  }
}
