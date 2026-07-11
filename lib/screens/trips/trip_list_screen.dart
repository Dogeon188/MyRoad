import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/screens/trips/create_trip_screen.dart';
import 'package:myroad/screens/trips/trip_dashboard_screen.dart';
import 'package:myroad/services/json_export_service.dart';
import 'package:myroad/services/json_import_service.dart';
import 'package:myroad/services/png_metadata.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/utils/spot_appearance.dart';
import 'package:myroad/widgets/dialogs.dart';
import 'package:myroad/widgets/icon_color_picker.dart';

class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tripDao = ref.watch(tripDaoProvider);

    return Scaffold(
      body: StreamBuilder<List<Trip>>(
        stream: tripDao.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final trips = snapshot.data!;
          if (trips.isEmpty) return Center(child: Text(l10n.noTrips));
          return StreamBuilder<Map<String, int>>(
            stream: tripDao.watchTripRegionCounts(),
            builder: (context, countsSnapshot) {
              final counts = countsSnapshot.data ?? {};
              return ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  12,
                  MediaQuery.of(context).padding.top + 12,
                  12,
                  12,
                ),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return _TripCard(
                    trip: trip,
                    regionCount: counts[trip.id] ?? 0,
                    l10n: l10n,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TripDashboardScreen(tripId: trip.id),
                      ),
                    ),
                    onExport: (cardContext) => _export(cardContext, ref, trip),
                    onEdit: (cardContext) =>
                        _edit(cardContext, ref, tripDao, trip),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'import',
            tooltip: l10n.importJson,
            onPressed: () => _importJson(context, ref),
            child: const Icon(Icons.file_open),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'create',
            tooltip: l10n.createTrip,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateTripScreen()),
            ),
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref, Trip trip) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.zero;
    final db = ref.read(appDatabaseProvider);
    final json = await JsonExportService(db).exportTrip(trip.id);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(json);
    final bytes = utf8.encode(jsonStr);
    final file = XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name: '${trip.name}.myroad.json',
    );
    await SharePlus.instance.share(
      ShareParams(files: [file], sharePositionOrigin: origin),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    TripDao dao,
    Trip trip,
  ) async {
    final result = await showDialog<EditTripResult>(
      context: context,
      builder: (_) => _EditTripDialog(trip: trip),
    );
    if (result != null) {
      await dao.updateTrip(
        trip.id,
        name: result.name,
        iconCode: Value(result.iconCode),
      );
    }
  }

  Future<void> _importJson(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.single.bytes == null) return;

    final bytes = result.files.single.bytes!;
    Map<String, dynamic> json;
    if (result.files.single.name.toLowerCase().endsWith('.png')) {
      final text = extractPngText(bytes);
      if (text == null) {
        if (!context.mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.importNoDataFound)));
        return;
      }
      json = jsonDecode(text) as Map<String, dynamic>;
    } else {
      json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    }

    final db = ref.read(appDatabaseProvider);
    final importService = JsonImportService(db);

    String? newTripId;
    if (json['type'] == 'trip') {
      newTripId = await importService.importTrip(json);
    } else if (json['type'] == 'region') {
      await importService.importRegion(json);
    }

    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.importSuccess)));
    if (newTripId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripDashboardScreen(tripId: newTripId!),
        ),
      );
    }
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final int regionCount;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final void Function(BuildContext) onExport;
  final void Function(BuildContext) onEdit;

  const _TripCard({
    required this.trip,
    required this.regionCount,
    required this.l10n,
    required this.onTap,
    required this.onExport,
    required this.onEdit,
  });

  IconData _transportIcon(String mode) => switch (mode) {
    'walk' => Icons.directions_walk,
    'transit' => Icons.directions_transit,
    'car' => Icons.directions_car,
    'bicycle' => Icons.directions_bike,
    _ => Icons.directions_walk,
  };

  String _transportLabel(String mode) => switch (mode) {
    'walk' => l10n.walk,
    'transit' => l10n.publicTransit,
    'car' => l10n.car,
    'bicycle' => l10n.bicycle,
    _ => mode,
  };

  int? _dayCount(Trip trip) {
    if (trip.startDate != null && trip.endDate != null) {
      return trip.endDate!.difference(trip.startDate!).inDays + 1;
    }
    return null;
  }

  String? _formatDateRange(Trip trip) {
    final df = DateFormat.MMMd();
    final wf = DateFormat.E();
    if (trip.startDate != null && trip.endDate != null) {
      return '${wf.format(trip.startDate!)}, ${df.format(trip.startDate!)} – ${wf.format(trip.endDate!)}, ${df.format(trip.endDate!)}';
    } else if (trip.startDate != null) {
      return '${wf.format(trip.startDate!)}, ${df.format(trip.startDate!)} –';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateRange = _formatDateRange(trip);
    final days = _dayCount(trip);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    tripIcon(iconCode: trip.iconCode),
                    size: 20,
                    color: tripColor(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(trip.name, style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share),
                    tooltip: l10n.export,
                    iconSize: 20,
                    onPressed: () => onExport(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: l10n.editTrip,
                    iconSize: 20,
                    onPressed: () => onEdit(context),
                  ),
                ],
              ),
              if (dateRange != null || days != null) ...[
                const SizedBox(height: 4),
                Text(
                  [?dateRange, if (days != null) l10n.nDays(days)].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    _transportIcon(trip.transportPreference),
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _transportLabel(trip.transportPreference),
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.public_outlined,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.nRegions(regionCount),
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef EditTripResult = ({String name, int? iconCode});

class _EditTripDialog extends ConsumerStatefulWidget {
  final Trip trip;
  const _EditTripDialog({required this.trip});

  @override
  ConsumerState<_EditTripDialog> createState() => _EditTripDialogState();
}

class _EditTripDialogState extends ConsumerState<_EditTripDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.trip.name,
  );
  late int? _iconCode = widget.trip.iconCode;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, iconCode: _iconCode));
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    if (await showConfirmDialog(
      context,
      title: l10n.delete,
      content: l10n.deleteTripConfirm(widget.trip.name),
    )) {
      await ref.read(tripDaoProvider).deleteTrip(widget.trip.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.editTrip)),
          IconButton(
            onPressed: _delete,
            tooltip: l10n.delete,
            icon: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconPickerButton(
              current: tripIcon(iconCode: _iconCode),
              color: tripColor(),
              tooltip: l10n.icon,
              onPicked: (icon) => setState(() => _iconCode = icon?.codePoint),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  label: requiredLabel(l10n.tripName),
                ),
                autofocus: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
