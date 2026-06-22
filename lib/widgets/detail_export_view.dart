import 'package:flutter/material.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/services/png_export_service.dart';
import 'package:myroad/widgets/transport_arrow.dart';

class DetailExportView extends StatelessWidget {
  final DetailDayData data;

  const DetailExportView({super.key, required this.data});

  String _formatDate(DateTime d) => '${d.year}/${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    String? lastPhysicalSpotId;
    String? lastAreaName;

    for (final entry in data.entries) {
      final physId = entry.physicalSpotId;

      // Transport between consecutive physical spots
      if (physId != null && lastPhysicalSpotId != null) {
        final key = '$lastPhysicalSpotId->$physId';
        final legs = data.transports[key];
        if (legs != null && legs.isNotEmpty) {
          for (final leg in legs) {
            widgets.add(TransportArrow(
              mode: leg.mode,
              durationMinutes: leg.estimatedDurationMinutes,
              distanceMeters: leg.distanceMeters,
              routeName: leg.routeName,
              price: leg.price,
            ));
          }
        } else {
          widgets.add(const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 2),
            child: Row(children: [
              Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
            ]),
          ));
        }
      }

      if (entry.isHotelAction) {
        widgets.add(_ExportSpotBlock.hotel(type: entry.itemType!, hotelName: entry.hotelName));
      } else {
        // Area header
        if (entry.areaName != lastAreaName) {
          lastAreaName = entry.areaName;
          widgets.add(Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
            child: Text(
              entry.areaName ?? '',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ));
        }

        widgets.add(_ExportSpotBlock(spot: entry.spot!));
      }

      if (physId != null) lastPhysicalSpotId = physId;
    }

    return Container(
      width: 380,
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.tripName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Day ${data.dayNumber}${data.date != null ? ' — ${_formatDate(data.date!)}' : ''}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          ...widgets,
        ],
      ),
    );
  }

}

Color _spotColor(String type) => switch (type) {
  'restaurant' => Colors.orange,
  'hotel' || 'checkin' || 'checkout' || 'luggage' || 'depart' || 'return' => Colors.purple,
  'online' => Colors.teal,
  'custom' => Colors.grey,
  _ => Colors.blue,
};

IconData _spotIcon(String type) => switch (type) {
  'restaurant' => Icons.restaurant,
  'hotel' => Icons.hotel,
  'checkin' => Icons.login,
  'checkout' => Icons.logout,
  'luggage' => Icons.luggage,
  'depart' => Icons.directions_walk,
  'return' => Icons.night_shelter,
  'online' => Icons.videocam,
  'custom' => Icons.star_outline,
  _ => Icons.place,
};

class _ExportSpotBlock extends StatelessWidget {
  final Spot? spot;
  final String? hotelType;

  const _ExportSpotBlock({required this.spot}) : hotelType = null, hotelName = null;
  final String? hotelName;

  const _ExportSpotBlock.hotel({required String type, this.hotelName}) : hotelType = type, spot = null;

  static String _hotelLabel(String type) => switch (type) {
    'checkin' => 'Check-in',
    'checkout' => 'Check-out',
    'luggage' => 'Luggage',
    'depart' => 'Depart',
    'return' => 'Return to hotel',
    _ => type,
  };

  @override
  Widget build(BuildContext context) {
    final label = spot?.name ?? (hotelName != null ? '${_hotelLabel(hotelType!)} — $hotelName' : _hotelLabel(hotelType!));
    final type = spot?.type ?? hotelType!;
    final color = _spotColor(type);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(_spotIcon(type), color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                if (spot != null && spot!.estimatedVisitDurationMinutes > 0)
                  Text('${spot!.estimatedVisitDurationMinutes}min', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
