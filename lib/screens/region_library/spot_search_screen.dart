import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/api/places_api_client.dart';
import 'package:myroad/services/providers.dart';

class SpotSearchScreen extends ConsumerStatefulWidget {
  final String zoneId;

  const SpotSearchScreen({super.key, required this.zoneId});

  @override
  ConsumerState<SpotSearchScreen> createState() => _SpotSearchScreenState();
}

class _SpotSearchScreenState extends ConsumerState<SpotSearchScreen> {
  final _searchController = TextEditingController();
  final _linkController = TextEditingController();
  final _client = PlacesApiClient();
  List<PlaceSearchResult> _results = [];
  Timer? _debounce;
  bool _loading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _linkController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.length >= 2) _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final results = await _client.searchText(query);
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  Future<void> _addFromResult(PlaceSearchResult result) async {
    final spotDao = ref.read(spotDaoProvider);
    final details = await _client.getPlaceDetails(result.placeId);
    if (!mounted) return;

    final spotId = await spotDao.insertSpot(
      name: result.name,
      zoneId: widget.zoneId,
      type: 'spot',
      lat: result.lat,
      lng: result.lng,
      address: result.address,
      googlePlaceId: result.placeId,
      previewImageUrl: details != null && details.photoReferences.isNotEmpty
          ? _client.getPhotoUrl(details.photoReferences.first)
          : null,
    );

    if (details != null) {
      for (final period in details.openingHours) {
        await spotDao.addOpeningHours(
          spotId,
          day: period.day,
          openMinutes: period.openMinutes,
          closeMinutes: period.closeMinutes,
        );
      }
    }

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _addFromLink() async {
    final url = _linkController.text.trim();
    if (url.isEmpty) return;

    final result = await _client.resolveFromUrl(url);
    if (result == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.couldNotParseLink)),
        );
      }
      return;
    }

    await _addFromResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchSpots)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchPlaceholder,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _linkController,
                    decoration: InputDecoration(
                      hintText: l10n.pasteLink,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addFromLink,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(child: Text(l10n.noResults))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final r = _results[index];
                      return ListTile(
                        leading: const Icon(Icons.place),
                        title: Text(r.name),
                        subtitle: Text(r.address),
                        onTap: () => _addFromResult(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
