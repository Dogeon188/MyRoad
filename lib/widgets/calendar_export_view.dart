import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/png_export_service.dart';
import 'package:myroad/utils/spot_appearance.dart';

const _dayColumnWidth = 180.0;
const _dayColumnGap = 8.0;
const _dayColumnStride = _dayColumnWidth + _dayColumnGap;

class CalendarExportView extends StatelessWidget {
  final CalendarExportData data;

  const CalendarExportView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              data.tripName,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          _SegmentRow(
            segments: data.regionSegments,
            color: Colors.teal,
            icon: Icons.map,
          ),
          const SizedBox(height: 4),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: data.days
                  .map((day) => _DayColumn(day: day, l10n: l10n))
                  .toList(),
            ),
          ),
          const SizedBox(height: 4),
          _SegmentRow(
            segments: data.hotelSegments,
            color: Colors.purple,
            icon: Icons.hotel,
          ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final CalendarDayData day;
  final AppLocalizations l10n;
  const _DayColumn({required this.day, required this.l10n});

  String _formatDate(DateTime d) =>
      '${d.month}/${d.day} ${DateFormat.E().format(d)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _dayColumnWidth,
      margin: const EdgeInsets.only(right: _dayColumnGap),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Text(
                  l10n.dayN(day.dayNumber),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (day.date != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(day.date!),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 4),
          ...day.entries.map(
            (e) => e.isHotelAction
                ? _HotelItem(type: e.itemType!, l10n: l10n)
                : _AreaItem(entry: e),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _HotelItem extends StatelessWidget {
  final String type;
  final AppLocalizations l10n;
  const _HotelItem({required this.type, required this.l10n});

  static ({IconData icon, String label}) _info(
    AppLocalizations l10n,
    String type,
  ) => switch (type) {
    'checkin' => (icon: Icons.login, label: l10n.addCheckin),
    'checkout' => (icon: Icons.logout, label: l10n.addCheckout),
    'luggage' => (icon: Icons.luggage, label: l10n.addLuggage),
    'depart' => (icon: Icons.directions_walk, label: l10n.hotelDepart),
    'return' => (icon: Icons.night_shelter, label: l10n.hotelReturn),
    _ => (icon: Icons.help_outline, label: type),
  };

  @override
  Widget build(BuildContext context) {
    final info = _info(l10n, type);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(info.icon, size: 14, color: Colors.purple),
            const SizedBox(width: 6),
            Text(
              info.label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaItem extends StatelessWidget {
  final CalendarEntry entry;
  const _AreaItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Text(
              entry.areaName!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...entry.spots!.map(
            (spot) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: spotColor(
                      spot.type,
                      colorValue: spot.colorValue,
                    ),
                    radius: 4,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      spot.name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final List<CalendarSegment> segments;
  final MaterialColor color;
  final IconData icon;

  const _SegmentRow({
    required this.segments,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: segments.map((seg) {
        final width = seg.span * _dayColumnStride - _dayColumnGap;
        if (seg.name == null) {
          return SizedBox(width: width + _dayColumnGap);
        }
        return Container(
          width: width,
          height: 28,
          margin: const EdgeInsets.only(right: _dayColumnGap),
          decoration: BoxDecoration(
            color: color[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color[200]!),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  seg.name!,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
