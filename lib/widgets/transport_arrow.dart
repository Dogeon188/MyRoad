import 'package:flutter/material.dart';

class TransportArrow extends StatelessWidget {
  final String mode;
  final int durationMinutes;
  final double? distanceMeters;
  final String? routeName;
  final String? price;
  final String currencyPrefix;
  final String? notes;
  final EdgeInsetsGeometry padding;

  const TransportArrow({
    super.key,
    required this.mode,
    required this.durationMinutes,
    this.distanceMeters,
    this.routeName,
    this.price,
    this.currencyPrefix = '¥',
    this.notes,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 2),
  });

  IconData get _modeIcon => switch (mode) {
    'transit' => Icons.directions_bus,
    'car' => Icons.directions_car,
    'bicycle' => Icons.directions_bike,
    _ => Icons.directions_walk,
  };

  @override
  Widget build(BuildContext context) {
    final distText = distanceMeters != null && mode != 'transit'
        ? distanceMeters! >= 1000
              ? ' · ${(distanceMeters! / 1000).toStringAsFixed(1)} km'
              : ' · ${distanceMeters!.round()} m'
        : '';

    return Padding(
      padding: padding,
      child: Row(
        children: [
          const Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Icon(_modeIcon, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              [
                '${durationMinutes}min$distText',
                ?routeName,
                if (price != null) '$currencyPrefix$price',
                ?notes,
              ].join(' · '),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
