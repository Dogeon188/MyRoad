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
import 'package:drift/drift.dart' show OrderingTerm, Value;
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
              Builder(builder: (ctx) => OutlinedButton.icon(
                onPressed: () => _shareTrip(ctx, ref),
                icon: const Icon(Icons.share),
                label: Text(l10n.shareTrip),
              )),
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
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    final db = ref.read(appDatabaseProvider);
    final trip = await (db.select(db.trips)..where((t) => t.id.equals(tripId))).getSingleOrNull();
    if (trip == null) return;

    final regions = await ref.read(regionDaoProvider).watchByTrip(tripId).first;
    final buf = StringBuffer('${trip.name}\n');
    for (final region in regions) {
      final regionRating = region.rating == 1 ? ' 👍' : region.rating == -1 ? ' 👎' : '';
      if ((region.review != null && region.review!.isNotEmpty) || regionRating.isNotEmpty) {
        buf.writeln('\n${region.name}$regionRating${region.review != null && region.review!.isNotEmpty ? ': ${region.review}' : ''}');
      }
      final areas = await (db.select(db.areas)..where((t) => t.regionId.equals(region.id))).get();
      for (final area in areas) {
        final areaRating = area.rating == 1 ? ' 👍' : area.rating == -1 ? ' 👎' : '';
        if ((area.review != null && area.review!.isNotEmpty) || areaRating.isNotEmpty) {
          buf.writeln('\n${area.name}$areaRating${area.review != null && area.review!.isNotEmpty ? ': ${area.review}' : ''}');
        }
        final spots = await (db.select(db.spots)..where((t) => t.areaId.equals(area.id))).get();
        for (final spot in spots) {
          final spotRating = spot.rating == 1 ? ' 👍' : spot.rating == -1 ? ' 👎' : '';
          if ((spot.review != null && spot.review!.isNotEmpty) || spotRating.isNotEmpty) {
            buf.writeln('\n${spot.name}$spotRating${spot.review != null && spot.review!.isNotEmpty ? ': ${spot.review}' : ''}');
          }
        }
      }
    }
    await Share.share(buf.toString(), sharePositionOrigin: origin);
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _reviewController,
                    decoration: InputDecoration(
                      hintText: l10n.writeComment,
                      prefixIcon: const Icon(Icons.rate_review_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (v) => regionDao.updateRegion(widget.region.id, review: v),
                  ),
                ),
                StreamBuilder<Region?>(
                  stream: (widget.db.select(widget.db.regions)..where((t) => t.id.equals(widget.region.id))).watchSingleOrNull(),
                  builder: (context, snap) => _RatingToggle(
                    rating: snap.data?.rating,
                    onChanged: (v) => regionDao.updateRegion(widget.region.id, rating: Value(v)),
                  ),
                ),
              ],
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _reviewController,
                    decoration: InputDecoration(
                      hintText: l10n.writeComment,
                      prefixIcon: const Icon(Icons.rate_review_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (v) => widget.areaDao.updateArea(widget.area.id, review: v),
                  ),
                ),
                StreamBuilder<Area?>(
                  stream: (widget.db.select(widget.db.areas)..where((t) => t.id.equals(widget.area.id))).watchSingleOrNull(),
                  builder: (context, snap) => _RatingToggle(
                    rating: snap.data?.rating,
                    onChanged: (v) => widget.areaDao.updateArea(widget.area.id, rating: Value(v)),
                  ),
                ),
              ],
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

class _RatingToggle extends StatelessWidget {
  final int? rating;
  final ValueChanged<int?> onChanged;

  const _RatingToggle({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.thumb_up, color: rating == 1 ? Colors.green : null),
          onPressed: () => onChanged(rating == 1 ? null : 1),
        ),
        IconButton(
          icon: Icon(Icons.thumb_down, color: rating == -1 ? Colors.red : null),
          onPressed: () => onChanged(rating == -1 ? null : -1),
        ),
      ],
    );
  }
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _reviewController,
                    decoration: InputDecoration(
                      hintText: l10n.writeReview,
                      prefixIcon: const Icon(Icons.rate_review_outlined),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                    onChanged: (v) =>
                        widget.spotDao.updateSpot(widget.spot.id, review: v),
                  ),
                ),
                _RatingToggle(
                  rating: widget.spot.rating,
                  onChanged: (v) => widget.spotDao.updateSpot(widget.spot.id, rating: Value(v)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
