import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/screens/trips/create_trip_screen.dart';
import 'package:myroad/screens/trips/trip_dashboard_screen.dart';
import 'package:myroad/services/json_import_service.dart';
import 'package:myroad/services/png_metadata.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/widgets/dialogs.dart';
import 'package:myroad/widgets/name_input_dialog.dart';

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
                padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 12, 12, 12),
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
                    onRename: () => _rename(context, l10n, tripDao, trip),
                    onDelete: () => _confirmDelete(context, l10n, tripDao, trip),
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
            onPressed: () => _importJson(context, ref),
            child: const Icon(Icons.file_open),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'create',
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

  void _rename(
      BuildContext context, AppLocalizations l10n, TripDao dao, Trip trip) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => NameInputDialog(
        title: l10n.rename,
        labelText: l10n.tripName,
        initialValue: trip.name,
      ),
    );
    if (name != null) await dao.updateTrip(trip.id, name: name);
  }

  void _confirmDelete(
      BuildContext context, AppLocalizations l10n, TripDao dao, Trip trip) async {
    if (await showConfirmDialog(context, title: l10n.delete, content: l10n.deleteTripConfirm(trip.name))) {
      await dao.deleteTrip(trip.id);
    }
  }

  Future<void> _importJson(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    Map<String, dynamic> json;
    if (file.path.toLowerCase().endsWith('.png')) {
      final text = extractPngText(await file.readAsBytes());
      if (text == null) {
        if (!context.mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.importNoDataFound)));
        return;
      }
      json = jsonDecode(text) as Map<String, dynamic>;
    } else {
      final jsonStr = await file.readAsString();
      json = jsonDecode(jsonStr) as Map<String, dynamic>;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.importSuccess)),
    );
    if (newTripId != null) {
      Navigator.push(context,
        MaterialPageRoute(builder: (_) => TripDashboardScreen(tripId: newTripId!)),
      );
    }
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final int regionCount;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _TripCard({
    required this.trip,
    required this.regionCount,
    required this.l10n,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
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
    if (trip.startDate != null && trip.endDate != null) {
      return '${df.format(trip.startDate!)} – ${df.format(trip.endDate!)}';
    } else if (trip.startDate != null) {
      return '${df.format(trip.startDate!)} –';
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
                  Expanded(
                    child: Text(trip.name, style: theme.textTheme.titleMedium),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) => switch (action) {
                      'rename' => onRename(),
                      'delete' => onDelete(),
                      _ => null,
                    },
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
                      PopupMenuItem(value: 'delete', child: Text(l10n.delete, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                    ],
                  ),
                ],
              ),
              if (dateRange != null || days != null) ...[
                const SizedBox(height: 4),
                Text(
                  [
                    ?dateRange,
                    if (days != null) l10n.nDays(days),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(_transportIcon(trip.transportPreference),
                      size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(_transportLabel(trip.transportPreference),
                      style: theme.textTheme.labelMedium),
                  const SizedBox(width: 16),
                  Icon(Icons.public_outlined,
                      size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(l10n.nRegions(regionCount),
                      style: theme.textTheme.labelMedium),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
