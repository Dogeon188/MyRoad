import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/database/dao/area_dao.dart';
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
                  return StreamBuilder<List<Area>>(
                    stream: (db.select(db.areas)
                          ..where((t) => t.regionId.equals(region.id))
                          ..orderBy([(t) => OrderingTerm.asc(t.order)]))
                        .watch(),
                    builder: (context, areaSnap) {
                      final areaCount = areaSnap.data?.length ?? 0;
                      return ListTile(
                        title: Text(region.name),
                        subtitle: Text(l10n.nAreas(areaCount)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _RegionReviewPage(
                              region: region,
                              db: db,
                            ),
                          ),
                        ),
                      );
                    },
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
      if (region.review != null && region.review!.isNotEmpty) {
        buf.writeln('\n${region.name}: ${region.review}');
      }
      final areas = await (db.select(db.areas)..where((t) => t.regionId.equals(region.id))).get();
      for (final area in areas) {
        if (area.review != null && area.review!.isNotEmpty) {
          buf.writeln('\n${area.name}: ${area.review}');
        }
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

class _RegionReviewPage extends ConsumerStatefulWidget {
  final Region region;
  final AppDatabase db;

  const _RegionReviewPage({required this.region, required this.db});

  @override
  ConsumerState<_RegionReviewPage> createState() => _RegionReviewPageState();
}

class _RegionReviewPageState extends ConsumerState<_RegionReviewPage> {
  late TextEditingController _reviewController;

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController(text: widget.region.review);
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final regionDao = ref.watch(regionDaoProvider);
    final areaDao = ref.watch(areaDaoProvider);
    final spotDao = ref.watch(spotDaoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.region.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _reviewController,
              decoration: InputDecoration(
                hintText: l10n.writeComment,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (v) => regionDao.updateRegion(widget.region.id, review: v),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Area>>(
              stream: areaDao.watchByRegion(widget.region.id),
              builder: (context, areaSnap) {
                final areas = areaSnap.data ?? [];
                if (areas.isEmpty) return const SizedBox.shrink();
                return ListView.builder(
                  itemCount: areas.length,
                  itemBuilder: (context, i) {
                    final area = areas[i];
                    return ListTile(
                      title: Text(area.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _AreaReviewPage(
                            area: area,
                            db: widget.db,
                            spotDao: spotDao,
                            areaDao: areaDao,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaReviewPage extends StatefulWidget {
  final Area area;
  final AppDatabase db;
  final SpotDao spotDao;
  final AreaDao areaDao;

  const _AreaReviewPage({
    required this.area,
    required this.db,
    required this.spotDao,
    required this.areaDao,
  });

  @override
  State<_AreaReviewPage> createState() => _AreaReviewPageState();
}

class _AreaReviewPageState extends State<_AreaReviewPage> {
  late TextEditingController _reviewController;

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController(text: widget.area.review);
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.area.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _reviewController,
              decoration: InputDecoration(
                hintText: l10n.writeComment,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (v) => widget.areaDao.updateArea(widget.area.id, review: v),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Spot>>(
              stream: widget.spotDao.watchByArea(widget.area.id),
              builder: (context, spotSnap) {
                final spots = spotSnap.data ?? [];
                if (spots.isEmpty) return const SizedBox.shrink();
                return ListView.builder(
                  itemCount: spots.length,
                  itemBuilder: (context, i) => _SpotReviewTile(
                    spot: spots[i],
                    spotDao: widget.spotDao,
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
