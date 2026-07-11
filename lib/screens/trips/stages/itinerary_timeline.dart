import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/models/enums.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/utils/spot_appearance.dart';
import 'package:myroad/utils/url_helper.dart';
import 'package:myroad/widgets/transport_arrow.dart';
import 'package:myroad/screens/trips/stages/transport_edit_sheet.dart';

String formatTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Width of the rail column holding the timeline dot + connecting line.
const _railWidth = 20.0;

/// Diameter of the timeline dot.
const _dotSize = 12.0;

/// Width of the connecting line inside the rail.
const _lineWidth = 2.0;

/// Width of the time label column on spot/hotel rows.
const _timeColumnWidth = 44.0;

/// Gap between the time column (or its equivalent) and the row content.
const _contentGap = 4.0;

/// Gap used by rows with no time column (transport, skeleton) so their
/// content still lines up with rows that do have one.
const _noTimeGap = _timeColumnWidth + _contentGap;

enum RowKind { spot, transport, hotel }

class TimelineRow {
  final RowKind kind;
  final String? name;
  final String? type;
  final int? iconCode;
  final int? colorValue;
  final int? timeMinutes;
  final String? subtitle;
  final String? note;
  final String? areaLabel;
  final String? warning;
  final String? url;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAreaTap;
  final void Function(BuildContext context)? onTimeTap;
  final bool skipped;

  // transport fields
  final AppDatabase? db;
  final String? tripId;
  final String? fromSpotId;
  final String? toSpotId;
  final DateTime? departTime;
  final DateTime? arrivalTime;
  // hotel fields
  final String? hotelSpotId;
  final SpotDao? spotDao;

  TimelineRow._({
    required this.kind,
    this.name,
    this.colorValue,
    this.type,
    this.iconCode,
    this.timeMinutes,
    this.subtitle,
    this.note,
    this.areaLabel,
    this.warning,
    this.url,
    this.onTap,
    this.onLongPress,
    this.onAreaTap,
    this.onTimeTap,
    this.skipped = false,
    this.db,
    this.tripId,
    this.fromSpotId,
    this.toSpotId,
    this.departTime,
    this.arrivalTime,
    this.hotelSpotId,
    this.spotDao,
  });

  factory TimelineRow.spot({
    required String name,
    required String type,
    int? iconCode,
    int? colorValue,
    int? timeMinutes,
    String? subtitle,
    String? note,
    String? areaLabel,
    String? warning,
    String? url,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    VoidCallback? onAreaTap,
    void Function(BuildContext context)? onTimeTap,
    bool skipped = false,
  }) => TimelineRow._(
    kind: RowKind.spot,
    name: name,
    type: type,
    iconCode: iconCode,
    colorValue: colorValue,
    timeMinutes: timeMinutes,
    subtitle: subtitle,
    note: note,
    areaLabel: areaLabel,
    warning: warning,
    url: url,
    onTap: onTap,
    onLongPress: onLongPress,
    onAreaTap: onAreaTap,
    onTimeTap: onTimeTap,
    skipped: skipped,
  );

  factory TimelineRow.transport({
    required AppDatabase db,
    required String tripId,
    required String fromSpotId,
    required String toSpotId,
    DateTime? departTime,
    DateTime? arrivalTime,
  }) => TimelineRow._(
    kind: RowKind.transport,
    db: db,
    tripId: tripId,
    fromSpotId: fromSpotId,
    toSpotId: toSpotId,
    departTime: departTime,
    arrivalTime: arrivalTime,
  );

  factory TimelineRow.hotel({
    required String spotId,
    required SpotDao spotDao,
    int? timeMinutes,
    void Function(BuildContext context)? onTimeTap,
    VoidCallback? onTap,
  }) => TimelineRow._(
    kind: RowKind.hotel,
    hotelSpotId: spotId,
    spotDao: spotDao,
    timeMinutes: timeMinutes,
    onTimeTap: onTimeTap,
    onTap: onTap,
  );
}

class TimelineSkeleton extends StatelessWidget {
  const TimelineSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final lineColor = Colors.grey[300]!;
    final baseColor = Colors.grey[300]!;
    final highlightColor = Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: List.generate(
            4,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    SizedBox(
                      width: _railWidth,
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: Container(
                                width: _lineWidth,
                                color: i == 0 ? Colors.transparent : lineColor,
                              ),
                            ),
                          ),
                          Container(
                            width: _dotSize,
                            height: _dotSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: lineColor,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Container(
                                width: _lineWidth,
                                color: i == 3 ? Colors.transparent : lineColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: _noTimeGap),
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Timeline extends StatelessWidget {
  final List<TimelineRow> rows;
  const Timeline({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          _buildRow(
            context,
            rows[i],
            isFirst: i == 0,
            isLast: i == rows.length - 1,
          ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    TimelineRow row, {
    required bool isFirst,
    required bool isLast,
  }) {
    if (row.kind == RowKind.transport) {
      return _TransportTimelineRow(row: row, isFirst: isFirst, isLast: isLast);
    }
    if (row.kind == RowKind.hotel) {
      return _HotelTimelineRow(row: row, isFirst: isFirst, isLast: isLast);
    }
    // Spot row
    final color = spotColor(row.type!, colorValue: row.colorValue);
    final lineColor = Colors.grey[300]!;
    return Opacity(
      opacity: row.skipped ? 0.4 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (row.areaLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    SizedBox(
                      width: _railWidth,
                      child: Center(
                        child: Container(
                          width: _lineWidth,
                          color: isFirst ? Colors.transparent : lineColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(40, 8, 16, 2),
                        child: GestureDetector(
                          onTap: row.onAreaTap,
                          child: Text(
                            row.areaLabel!,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Timeline dot + line
                  SizedBox(
                    width: _railWidth,
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Container(
                              width: _lineWidth,
                              color: isFirst && row.areaLabel == null
                                  ? Colors.transparent
                                  : lineColor,
                            ),
                          ),
                        ),
                        Container(
                          width: _dotSize,
                          height: _dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Container(
                              width: _lineWidth,
                              color: isLast ? Colors.transparent : lineColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Time column — separate gesture target from the spot InkWell
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: row.onTimeTap != null
                        ? () => row.onTimeTap!(context)
                        : null,

                    child: SizedBox(
                      width: _timeColumnWidth,
                      child: Center(
                        child: row.timeMinutes != null
                            ? Text(
                                formatTime(row.timeMinutes!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              )
                            : row.onTimeTap != null
                            ? Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey[400],
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: _contentGap),
                  // Spot info
                  Expanded(
                    child: InkWell(
                      onTap: row.onTap,
                      onLongPress: row.onLongPress != null
                          ? () async {
                              final l10n = AppLocalizations.of(context)!;
                              final action = await showModalBottomSheet<String>(
                                context: context,
                                builder: (_) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (row.warning != null)
                                        ListTile(
                                          leading: const Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.red,
                                          ),
                                          title: Text(
                                            row.warning!,
                                            style: const TextStyle(
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ListTile(
                                        leading: Icon(
                                          row.skipped
                                              ? Icons.visibility
                                              : Icons.visibility_off,
                                        ),
                                        title: Text(
                                          row.skipped
                                              ? l10n.unskipSpot
                                              : l10n.skipSpot,
                                        ),
                                        onTap: () =>
                                            Navigator.pop(context, 'skip'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              if (action == 'skip') row.onLongPress!();
                            }
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: row.warning != null
                              ? Colors.red.withValues(alpha: 0.08)
                              : color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: row.warning != null
                                ? Colors.red.withValues(alpha: 0.6)
                                : color.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              spotIcon(row.type!, iconCode: row.iconCode),
                              color: color,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRect(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.name!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (row.subtitle != null)
                                      Text(
                                        row.subtitle!,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    if (row.note != null)
                                      Text(
                                        row.note!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (row.warning != null)
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: Colors.red,
                              ),
                            if (row.url != null)
                              IconButton(
                                icon: const Icon(Icons.open_in_new, size: 16),
                                tooltip: AppLocalizations.of(context)!.openLink,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => launchUrl(
                                  externalUri(row.url!),
                                  mode: LaunchMode.externalApplication,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportTimelineRow extends ConsumerStatefulWidget {
  final TimelineRow row;
  final bool isFirst;
  final bool isLast;
  const _TransportTimelineRow({
    required this.row,
    required this.isFirst,
    required this.isLast,
  });

  @override
  ConsumerState<_TransportTimelineRow> createState() =>
      _TransportTimelineRowState();
}

class _TransportTimelineRowState extends ConsumerState<_TransportTimelineRow> {
  List<Transport> _legs = [];
  String _currencyPrefix = '¥';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = widget.row.db!;
    final results =
        await (db.select(db.transports)..where(
              (t) =>
                  t.fromSpotId.equals(widget.row.fromSpotId!) &
                  t.toSpotId.equals(widget.row.toSpotId!),
            ))
            .get();
    final spot = await (db.select(
      db.spots,
    )..where((t) => t.id.equals(widget.row.fromSpotId!))).getSingleOrNull();
    if (spot != null) {
      final area = await (db.select(
        db.areas,
      )..where((t) => t.id.equals(spot.areaId))).getSingleOrNull();
      if (area != null) {
        final region = await (db.select(
          db.regions,
        )..where((t) => t.id.equals(area.regionId))).getSingleOrNull();
        if (region != null) _currencyPrefix = currencySymbol(region.currency);
      }
    }
    if (mounted) {
      setState(() {
        _legs = results;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox(height: 24);

    return GestureDetector(
      onTap: () => _showEditSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              SizedBox(
                width: _railWidth,
                child: Center(
                  child: Container(width: _lineWidth, color: Colors.grey[300]),
                ),
              ),
              const SizedBox(width: _noTimeGap),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _legs.isNotEmpty
                      ? Column(
                          children: _legs
                              .map(
                                (t) => TransportArrow(
                                  mode: t.mode,
                                  durationMinutes: t.estimatedDurationMinutes,
                                  distanceMeters: t.distanceMeters,
                                  routeName: t.routeName,
                                  price: t.price,
                                  currencyPrefix: _currencyPrefix,
                                  notes: t.notes,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                ),
                              )
                              .toList(),
                        )
                      : Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)!.tapToAddTransport,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
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
    );
  }

  void _showEditSheet(BuildContext context) async {
    final rootMessenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => TransportEditSheet(
        db: widget.row.db!,
        tripId: widget.row.tripId!,
        fromSpotId: widget.row.fromSpotId!,
        toSpotId: widget.row.toSpotId!,
        departTime: widget.row.departTime,
        arrivalTime: widget.row.arrivalTime,
        legs: _legs,
        currencyPrefix: _currencyPrefix,
        transportService: ref.read(transportServiceProvider),
        onChanged: () async {
          await _load();
        },
        rootMessenger: rootMessenger,
      ),
    );
    // ponytail: re-read after sheet closes — deactivate() save is fire-and-forget
    if (mounted) await _load();
  }
}

class _HotelTimelineRow extends StatelessWidget {
  final TimelineRow row;
  final bool isFirst;
  final bool isLast;
  const _HotelTimelineRow({
    required this.row,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Spot?>(
      future: row.spotDao!.getById(row.hotelSpotId!),
      builder: (context, snap) {
        final missing =
            snap.connectionState == ConnectionState.done && snap.data == null;
        final name = missing
            ? AppLocalizations.of(context)!.missingReference
            : (snap.data?.name ?? '...');
        final color = Colors.purple;
        final lineColor = Colors.grey[300]!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                SizedBox(
                  width: _railWidth,
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Container(
                            width: _lineWidth,
                            color: isFirst ? Colors.transparent : lineColor,
                          ),
                        ),
                      ),
                      Container(
                        width: _dotSize,
                        height: _dotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Container(
                            width: _lineWidth,
                            color: isLast ? Colors.transparent : lineColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: row.onTimeTap != null
                      ? () => row.onTimeTap!(context)
                      : null,

                  child: SizedBox(
                    width: _timeColumnWidth,
                    child: Center(
                      child: row.timeMinutes != null
                          ? Text(
                              formatTime(row.timeMinutes!),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                              textAlign: TextAlign.center,
                            )
                          : row.onTimeTap != null
                          ? Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[400],
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: _contentGap),
                Expanded(
                  child: MouseRegion(
                    cursor: (missing || row.onTap == null)
                        ? MouseCursor.defer
                        : SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: missing ? null : row.onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: color.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.hotel, color: color, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (missing)
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: Colors.red,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
