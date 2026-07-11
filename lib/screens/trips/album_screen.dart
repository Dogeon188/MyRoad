import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/database/database.dart';
import 'package:myroad/services/providers.dart';
import 'package:share_plus/share_plus.dart';

class AlbumScreen extends ConsumerStatefulWidget {
  final String tripId;

  const AlbumScreen({super.key, required this.tripId});

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  List<_AlbumPhoto>? _photos;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final db = ref.read(appDatabaseProvider);
    final regionDao = ref.read(regionDaoProvider);
    final spotDao = ref.read(spotDaoProvider);

    final regions = await regionDao.watchByTrip(widget.tripId).first;
    final photos = <_AlbumPhoto>[];

    for (final region in regions) {
      final areas = await (db.select(
        db.areas,
      )..where((t) => t.regionId.equals(region.id))).get();
      for (final area in areas) {
        final spots = await (db.select(
          db.spots,
        )..where((t) => t.areaId.equals(area.id))).get();
        for (final spot in spots) {
          final spotPhotos = await spotDao.getPhotos(spot.id);
          for (final photo in spotPhotos) {
            photos.add(
              _AlbumPhoto(
                uri: photo.uri,
                spotName: spot.name,
                lat: photo.lat ?? spot.lat,
                lng: photo.lng ?? spot.lng,
                caption: photo.caption,
              ),
            );
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _photos = photos;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.album),
        actions: [
          if (_photos != null && _photos!.isNotEmpty)
            IconButton(icon: const Icon(Icons.share), onPressed: _sharePhotos),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _photos!.isEmpty
          ? Center(child: Text(l10n.noPhotosYet))
          : _AlbumGrid(photos: _photos!),
    );
  }

  Future<void> _sharePhotos() async {
    final localPhotos = _photos!
        .where((p) => !p.uri.startsWith('http'))
        .map((p) => XFile(p.uri))
        .toList();
    if (localPhotos.isEmpty) return;
    await SharePlus.instance.share(ShareParams(files: localPhotos));
  }
}

class _AlbumPhoto {
  final String uri;
  final String spotName;
  final double? lat;
  final double? lng;
  final String? caption;

  _AlbumPhoto({
    required this.uri,
    required this.spotName,
    this.lat,
    this.lng,
    this.caption,
  });
}

class _AlbumGrid extends StatelessWidget {
  final List<_AlbumPhoto> photos;
  const _AlbumGrid({required this.photos});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  _PhotoViewScreen(photos: photos, initialIndex: index),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _buildImage(photo.uri),
          ),
        );
      },
    );
  }
}

Widget _buildImage(String uri, {BoxFit fit = BoxFit.cover}) {
  if (uri.startsWith('http')) {
    return Image.network(uri, fit: fit);
  }
  if (kIsWeb) return const SizedBox.shrink();
  return Image.file(File(uri), fit: fit);
}

class _PhotoViewScreen extends StatefulWidget {
  final List<_AlbumPhoto> photos;
  final int initialIndex;

  const _PhotoViewScreen({required this.photos, required this.initialIndex});

  @override
  State<_PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<_PhotoViewScreen> {
  late PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_current];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(photo.spotName),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, i) {
          final p = widget.photos[i];
          return InteractiveViewer(
            child: Center(child: _buildImage(p.uri, fit: BoxFit.contain)),
          );
        },
      ),
    );
  }
}
