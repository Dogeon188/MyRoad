import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          return ListView.builder(
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return ListTile(
                title: Text(trip.name),
                subtitle: Text('${trip.planMode} · ${trip.transportPreference}'),
                onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => TripDashboardScreen(tripId: trip.id))),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, l10n, tripDao, trip),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CreateTripScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppLocalizations l10n, TripDao dao, Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteTripConfirm(trip.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed == true) await dao.deleteTrip(trip.id);
  }
}
