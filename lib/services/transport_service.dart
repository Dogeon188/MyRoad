import 'package:drift/drift.dart';
import 'package:myroad/api/directions_api_client.dart';
import 'package:myroad/database/database.dart';

class TransportService {
  final AppDatabase _db;
  final DirectionsApiClient _directionsClient;

  TransportService(this._db, this._directionsClient);

  Future<Transport?> getOrFetchTransport({
    required String fromSpotId,
    required String toSpotId,
    required String tripId,
    required String mode,
  }) async {
    final cached = await (_db.select(_db.transports)
          ..where((t) =>
              t.fromSpotId.equals(fromSpotId) &
              t.toSpotId.equals(toSpotId) &
              t.mode.equals(mode)))
        .getSingleOrNull();

    if (cached != null) return cached;

    final fromSpot = await (_db.select(_db.spots)
          ..where((t) => t.id.equals(fromSpotId)))
        .getSingleOrNull();
    final toSpot = await (_db.select(_db.spots)
          ..where((t) => t.id.equals(toSpotId)))
        .getSingleOrNull();
    if (fromSpot == null || toSpot == null) return null;
    if (fromSpot.lat == null || fromSpot.lng == null || toSpot.lat == null || toSpot.lng == null) return null;

    final result = await _directionsClient.getRoute(
      originLat: fromSpot.lat!,
      originLng: fromSpot.lng!,
      destLat: toSpot.lat!,
      destLng: toSpot.lng!,
      mode: mode,
    );

    if (result == null) return null;

    return await _db.into(_db.transports).insertReturning(
          TransportsCompanion.insert(
            tripId: tripId,
            fromSpotId: fromSpotId,
            toSpotId: toSpotId,
            mode: Value(mode),
            estimatedDurationMinutes: result.durationMinutes,
            distanceMeters: Value(result.distanceMeters),
            routePolyline: Value(result.polyline),
          ),
        );
  }
}
