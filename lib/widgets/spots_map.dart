import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SpotsMap extends StatelessWidget {
  final List<MapSpot> spots;
  final void Function(String spotId)? onSpotTapped;

  const SpotsMap({super.key, required this.spots, this.onSpotTapped});

  static bool get supported =>
      kIsWeb || Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    if (!supported) {
      return const SizedBox.shrink();
    }

    if (spots.isEmpty) {
      return const SizedBox(height: 200, child: Center(child: Text('No spots to show on map')));
    }

    final markers = spots.map((s) => Marker(
      markerId: MarkerId(s.id),
      position: LatLng(s.lat, s.lng),
      infoWindow: InfoWindow(title: s.name),
      icon: _markerColor(s.type),
      onTap: () => onSpotTapped?.call(s.id),
    )).toSet();

    final center = LatLng(
      spots.map((s) => s.lat).reduce((a, b) => a + b) / spots.length,
      spots.map((s) => s.lng).reduce((a, b) => a + b) / spots.length,
    );

    return SizedBox(
      height: 300,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: 12),
        markers: markers,
        myLocationEnabled: false,
        zoomControlsEnabled: true,
      ),
    );
  }

  BitmapDescriptor _markerColor(String type) {
    return switch (type) {
      'restaurant' => BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      'hotel' => BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      'custom' => BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      _ => BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    };
  }
}

class MapSpot {
  final String id;
  final String name;
  final String type;
  final double lat;
  final double lng;

  MapSpot({required this.id, required this.name, required this.type, required this.lat, required this.lng});
}
