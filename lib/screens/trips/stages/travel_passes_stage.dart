import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myroad/database/dao/itinerary_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/models/enums.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/trips/stages/itinerary_view_stage.dart' show showPassDialog;

class TravelPassesStage extends ConsumerWidget {
  final String tripId;
  const TravelPassesStage({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final itineraryDao = ref.watch(itineraryDaoProvider);
    final passes = ref.watch(travelPassesProvider(tripId)).valueOrNull ?? [];
    final days = ref.watch(itineraryDaysProvider(tripId)).valueOrNull ?? [];
    final regions = ref.watch(tripRegionsProvider(tripId)).valueOrNull ?? [];
    final cp = regions.isNotEmpty ? currencySymbol(regions.first.currency) : '¥';

    return Scaffold(
      body: passes.isEmpty
          ? Center(child: Text(l10n.noPass, style: TextStyle(color: Colors.grey[500])))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: passes.length,
              itemBuilder: (context, i) => _PassCard(
                pass: passes[i],
                itineraryDao: itineraryDao,
                tripId: tripId,
                dayCount: days.length,
                currencyPrefix: cp,
                l10n: l10n,
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showPassDialog(context, itineraryDao, tripId, days.length),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PassCard extends StatelessWidget {
  final TravelPassesData pass;
  final ItineraryDao itineraryDao;
  final String tripId;
  final int dayCount;
  final String currencyPrefix;
  final AppLocalizations l10n;

  const _PassCard({
    required this.pass,
    required this.itineraryDao,
    required this.tripId,
    required this.dayCount,
    required this.currencyPrefix,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final dayText = pass.startDay == pass.endDay
        ? l10n.dayN(pass.startDay)
        : l10n.passDays(pass.startDay, pass.endDay);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showPassDialog(context, itineraryDao, tripId, dayCount, existing: pass),
        onLongPress: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.deletePass),
              content: Text(l10n.deletePassConfirm(pass.name)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: Text(l10n.delete),
                ),
              ],
            ),
          );
          if (confirm == true) await itineraryDao.deletePass(pass.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                pass.bought ? Icons.check_circle : Icons.confirmation_number_outlined,
                color: pass.bought ? Colors.green : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pass.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        dayText,
                        if (pass.price != null) '$currencyPrefix${pass.price!}',
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    if (pass.note != null && pass.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(pass.note!, style: TextStyle(fontSize: 12, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
              if (pass.url != null && pass.url!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 20),
                  onPressed: () => launchUrl(Uri.parse(pass.url!), mode: LaunchMode.externalApplication),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
