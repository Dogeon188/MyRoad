import 'package:flutter/material.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/png_export_service.dart';
import 'package:myroad/widgets/transport_arrow.dart';

String _formatTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

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

String _hotelLabel(AppLocalizations l10n, String type) => switch (type) {
  'checkin' => l10n.addCheckin,
  'checkout' => l10n.addCheckout,
  'luggage' => l10n.addLuggage,
  'depart' => l10n.hotelDepart,
  'return' => l10n.hotelReturn,
  _ => type,
};

class DetailExportView extends StatelessWidget {
  final DetailDayData data;

  const DetailExportView({super.key, required this.data});

  String _formatDate(DateTime d) => '${d.year}/${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Build timeline rows matching the list tab structure
    final rows = <_ExportRow>[];
    String? lastPhysicalSpotId;
    String? lastAreaName;

    for (final entry in data.entries) {
      final physId = entry.physicalSpotId;

      // Transport between consecutive physical spots
      if (physId != null && lastPhysicalSpotId != null) {
        final key = '$lastPhysicalSpotId->$physId';
        final legs = data.transports[key];
        rows.add(_ExportRow.transport(legs: legs ?? []));
      }

      if (entry.isHotelAction) {
        final label = entry.hotelName != null
            ? '${_hotelLabel(l10n, entry.itemType!)} — ${entry.hotelName}'
            : _hotelLabel(l10n, entry.itemType!);
        rows.add(_ExportRow.spot(
          name: label,
          type: entry.itemType!,
          timeMinutes: entry.timeMinutes,
        ));
      } else {
        final showArea = entry.areaName != lastAreaName;
        if (showArea) lastAreaName = entry.areaName;
        rows.add(_ExportRow.spot(
          name: entry.spot!.name,
          type: entry.spot!.type,
          timeMinutes: entry.timeMinutes,
          subtitle: entry.spot!.estimatedVisitDurationMinutes > 0
              ? '${entry.spot!.estimatedVisitDurationMinutes}min'
              : null,
          areaLabel: showArea ? entry.areaName : null,
        ));
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
            '${l10n.dayN(data.dayNumber)}${data.date != null ? ' — ${_formatDate(data.date!)}' : ''}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < rows.length; i++)
            _buildRow(context, rows[i], isFirst: i == 0, isLast: i == rows.length - 1),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, _ExportRow row, {required bool isFirst, required bool isLast}) {
    if (row.isTransport) {
      return _buildTransportRow(context, row, isFirst: isFirst, isLast: isLast);
    }
    return _buildSpotRow(context, row, isFirst: isFirst, isLast: isLast);
  }

  Widget _buildTransportRow(BuildContext context, _ExportRow row, {required bool isFirst, required bool isLast}) {
    final lineColor = Colors.grey[300]!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IntrinsicHeight(
        child: Row(
          children: [
            SizedBox(
              width: 16,
              child: Center(child: Container(width: 2, color: lineColor)),
            ),
            const SizedBox(width: 38),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: row.legs!.isNotEmpty
                    ? Column(
                        children: row.legs!.map((t) => TransportArrow(
                          mode: t.mode,
                          durationMinutes: t.estimatedDurationMinutes,
                          distanceMeters: t.distanceMeters,
                          routeName: t.routeName,
                          price: t.price,
                          notes: t.notes,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                        )).toList(),
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          Icon(Icons.arrow_downward, size: 14, color: Colors.grey),
                        ]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotRow(BuildContext context, _ExportRow row, {required bool isFirst, required bool isLast}) {
    final color = _spotColor(row.type!);
    final lineColor = Colors.grey[300]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (row.areaLabel != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: Center(child: Container(width: 2, color: isFirst ? Colors.transparent : lineColor)),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 6, 8, 2),
                      child: Text(row.areaLabel!,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 12,
                          )),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Timeline dot + line
                SizedBox(
                  width: 16,
                  child: Column(
                    children: [
                      Expanded(child: Center(child: Container(width: 2, color: isFirst && row.areaLabel == null ? Colors.transparent : lineColor))),
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                      ),
                      Expanded(child: Center(child: Container(width: 2, color: isLast ? Colors.transparent : lineColor))),
                    ],
                  ),
                ),
                // Time column
                SizedBox(
                  width: 36,
                  child: Center(
                    child: row.timeMinutes != null
                        ? Text(_formatTime(row.timeMinutes!),
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                            textAlign: TextAlign.center)
                        : null,
                  ),
                ),
                const SizedBox(width: 4),
                // Spot card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(_spotIcon(row.type!), color: color, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row.name!, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 12)),
                              if (row.subtitle != null)
                                Text(row.subtitle!, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExportRow {
  final String? name;
  final String? type;
  final int? timeMinutes;
  final String? subtitle;
  final String? areaLabel;
  final List<Transport>? legs;

  _ExportRow.spot({required String this.name, required String this.type, this.timeMinutes, this.subtitle, this.areaLabel})
      : legs = null;
  _ExportRow.transport({required List<Transport> this.legs})
      : name = null, type = null, timeMinutes = null, subtitle = null, areaLabel = null;

  bool get isTransport => legs != null;
}
