import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:myroad/database/dao/trip_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/screens/trips/create_trip_screen.dart';
import 'package:myroad/screens/trips/trip_dashboard_screen.dart';
import 'package:myroad/services/providers.dart';

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
          final trips = snapshot.data ?? [];
          if (trips.isEmpty) return Center(child: Text(l10n.noTrips));
          return StreamBuilder<Map<String, int>>(
            stream: tripDao.watchTripRegionCounts(),
            builder: (context, countsSnapshot) {
              final counts = countsSnapshot.data ?? {};
              return ListView.builder(
                padding: const EdgeInsets.all(12),
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
                    onDelete: () => _confirmDelete(context, l10n, tripDao, trip),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateTripScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppLocalizations l10n, TripDao dao, Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteTripConfirm(trip.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await dao.deleteTrip(trip.id);
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final int regionCount;
  final AppLocalizations l10n;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TripCard({
    required this.trip,
    required this.regionCount,
    required this.l10n,
    required this.onTap,
    required this.onDelete,
  });

  IconData _transportIcon(String mode) => switch (mode) {
        'walk' => Icons.directions_walk,
        'transit' => Icons.directions_transit,
        'car' => Icons.directions_car,
        'motorcycle' => Icons.two_wheeler,
        _ => Icons.directions_walk,
      };

  String _transportLabel(String mode) => switch (mode) {
        'walk' => l10n.walk,
        'transit' => l10n.publicTransit,
        'car' => l10n.car,
        'motorcycle' => l10n.motorcycle,
        _ => mode,
      };

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
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              if (dateRange != null) ...[
                const SizedBox(height: 4),
                Text(dateRange, style: theme.textTheme.bodySmall),
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
