import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/database/dao/spot_dao.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/services/providers.dart';
import 'package:myroad/screens/region_library/spot_detail_screen.dart';
import 'package:myroad/screens/trips/album_screen.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:share_plus/share_plus.dart';

class PostTripStage extends ConsumerWidget {
  final String tripId;

  const PostTripStage({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final regionDao = ref.watch(regionDaoProvider);
    final db = ref.watch(appDatabaseProvider);
    final spotDao = ref.watch(spotDaoProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AlbumScreen(tripId: tripId)),
                ),
                icon: const Icon(Icons.photo_library),
                label: Text(l10n.viewAlbum),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _shareTrip(context, ref),
                icon: const Icon(Icons.share),
                label: Text(l10n.shareTrip),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Region>>(
            stream: regionDao.watchByTrip(tripId),
            builder: (context, regionSnap) {
              final regions = regionSnap.data ?? [];
              if (regions.isEmpty) {
                return Center(child: Text(l10n.noRegionsInTrip));
              }
              return ListView.builder(
                itemCount: regions.length,
                itemBuilder: (context, i) {
                  final region = regions[i];
                  return _RegionReviewSection(
                    region: region,
                    db: db,
                    spotDao: spotDao,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _shareTrip(BuildContext context, WidgetRef ref) async {
    final db = ref.read(appDatabaseProvider);
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null) return;

    final regionDao = ref.read(regionDaoProvider);
    final regions = await regionDao.watchByTrip(tripId).first;
    final buf = StringBuffer('${trip.name}\n');
    for (final region in regions) {
      final areas = await (db.select(db.areas)..where((t) => t.regionId.equals(region.id))).get();
      for (final area in areas) {
        final spots = await (db.select(db.spots)..where((t) => t.areaId.equals(area.id))).get();
        for (final spot in spots) {
          if (spot.review != null && spot.review!.isNotEmpty) {
            buf.writeln('\n${spot.name}: ${spot.review}');
          }
        }
      }
    }
    await Share.shareXFiles([], text: buf.toString());
  }
}

class _RegionReviewSection extends StatelessWidget {
  final Region region;
  final AppDatabase db;
  final SpotDao spotDao;

  const _RegionReviewSection({
    required this.region,
    required this.db,
    required this.spotDao,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Area>>(
      stream: (db.select(db.areas)
            ..where((t) => t.regionId.equals(region.id))
            ..orderBy([(t) => OrderingTerm.asc(t.order)]))
          .watch(),
      builder: (context, areaSnap) {
        final areas = areaSnap.data ?? [];
        if (areas.isEmpty) return const SizedBox.shrink();
        return ExpansionTile(
          title: Text(region.name, style: Theme.of(context).textTheme.titleMedium),
          initiallyExpanded: true,
          children: [
            for (final area in areas)
              _AreaReviewSection(area: area, db: db, spotDao: spotDao),
          ],
        );
      },
    );
  }
}

class _AreaReviewSection extends StatelessWidget {
  final Area area;
  final AppDatabase db;
  final SpotDao spotDao;

  const _AreaReviewSection({
    required this.area,
    required this.db,
    required this.spotDao,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Spot>>(
      stream: spotDao.watchByArea(area.id),
      builder: (context, spotSnap) {
        final spots = spotSnap.data ?? [];
        if (spots.isEmpty) return const SizedBox.shrink();
        return ExpansionTile(
          title: Text(
            area.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                ),
          ),
          initiallyExpanded: true,
          children: [
            for (final spot in spots)
              _SpotReviewTile(spot: spot, spotDao: spotDao),
          ],
        );
      },
    );
  }
}

class _SpotReviewTile extends StatefulWidget {
  final Spot spot;
  final SpotDao spotDao;

  const _SpotReviewTile({required this.spot, required this.spotDao});

  @override
  State<_SpotReviewTile> createState() => _SpotReviewTileState();
}

class _SpotReviewTileState extends State<_SpotReviewTile> {
  late TextEditingController _reviewController;

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController(text: widget.spot.review);
  }

  @override
  void didUpdateWidget(_SpotReviewTile old) {
    super.didUpdateWidget(old);
    if (old.spot.id != widget.spot.id) {
      _reviewController.text = widget.spot.review ?? '';
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final previewUrl = widget.spot.previewImageUrl;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (previewUrl != null && previewUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: previewUrl.startsWith('http')
                        ? Image.network(previewUrl, width: 40, height: 40, fit: BoxFit.cover)
                        : Image.file(File(previewUrl), width: 40, height: 40, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    widget.spot.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 20),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SpotDetailScreen(spotId: widget.spot.id),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              decoration: InputDecoration(
                hintText: l10n.writeReview,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
              onChanged: (v) =>
                  widget.spotDao.updateSpot(widget.spot.id, review: v),
            ),
          ],
        ),
      ),
    );
  }
}
