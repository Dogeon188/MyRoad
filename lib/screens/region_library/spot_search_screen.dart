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
  final _controller = TextEditingController();
  PlacesApiClient? _client;
  PlacesApiClient get client =>
      _client ??= PlacesApiClient(languageCode: Localizations.localeOf(context).languageCode);
  List<PlaceSearchResult> _results = [];
  Timer? _debounce;
  bool _loading = false;

  static final _linkPattern = RegExp(r'https?://(goo\.gl|maps\.app|.*google\..*/maps|maps\.google)');

  bool _isLink(String input) => _linkPattern.hasMatch(input);

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String input) {
    _debounce?.cancel();
    if (input.trim().length < 2) return;

    if (_isLink(input.trim())) {
      _resolveLink(input.trim());
    } else {
      _debounce = Timer(const Duration(milliseconds: 300), () {
        _search(input.trim());
      });
    }
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    final results = await client.searchText(query);
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  Future<void> _resolveLink(String url) async {
    setState(() {
      _loading = true;
      _results = [];
    });
    final result = await client.resolveFromUrl(url);
    if (!mounted) return;

    if (result == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.couldNotParseLink)),
      );
      return;
    }

    setState(() {
      _results = [result];
      _loading = false;
    });
  }

  static String _inferSpotType(String? primaryType) {
    if (primaryType == null) return 'spot';
    if (primaryType.contains('restaurant') ||
        primaryType.contains('cafe') ||
        primaryType.contains('bakery') ||
        primaryType.contains('bar') ||
        primaryType.contains('food')) {
      return 'restaurant';
    }
    if (primaryType.contains('hotel') ||
        primaryType.contains('lodging') ||
        primaryType.contains('motel') ||
        primaryType.contains('hostel') ||
        primaryType.contains('resort')) {
      return 'hotel';
    }
    return 'spot';
  }

  Future<void> _addFromResult(PlaceSearchResult result) async {
    final spotDao = ref.read(spotDaoProvider);
    final details = await client.getPlaceDetails(result.placeId);
    if (!mounted) return;

    final spotId = await spotDao.insertSpot(
      name: result.name,
      zoneId: widget.zoneId,
      type: _inferSpotType(result.primaryType),
      lat: result.lat,
      lng: result.lng,
      address: result.address,
      googlePlaceId: result.placeId,
      previewImageUrl: details != null && details.photoReferences.isNotEmpty
          ? client.getPhotoUrl(details.photoReferences.first)
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

  Future<void> _addManually() async {
    final l10n = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController();
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    var type = 'spot';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.addSpot),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: l10n.spotName),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: InputDecoration(labelText: l10n.spotType),
                  items: [
                    DropdownMenuItem(value: 'spot', child: Text(l10n.spotTypeSpot)),
                    DropdownMenuItem(value: 'restaurant', child: Text(l10n.spotTypeRestaurant)),
                    DropdownMenuItem(value: 'hotel', child: Text(l10n.spotTypeHotel)),
                    DropdownMenuItem(value: 'online', child: Text(l10n.spotTypeOnline)),
                    DropdownMenuItem(value: 'custom', child: Text(l10n.spotTypeCustom)),
                  ],
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                if (type != 'online') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: latCtrl,
                    decoration: InputDecoration(labelText: l10n.latitude),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: lngCtrl,
                    decoration: InputDecoration(labelText: l10n.longitude),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: addressCtrl,
                  decoration: InputDecoration(labelText: l10n.address),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final lat = double.tryParse(latCtrl.text);
                final lng = double.tryParse(lngCtrl.text);
                if (name.isEmpty) return;
                if (type != 'online' && (lat == null || lng == null)) return;
                Navigator.pop(context, {
                  'name': name,
                  'type': type,
                  'lat': lat,
                  'lng': lng,
                  'address': addressCtrl.text.trim(),
                });
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    addressCtrl.dispose();

    if (result != null) {
      await ref.read(spotDaoProvider).insertSpot(
            name: result['name'] as String,
            zoneId: widget.zoneId,
            type: result['type'] as String,
            lat: result['lat'] as double?,
            lng: result['lng'] as double?,
            address: result['address'] as String?,
          );
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchSpots),
        actions: [
          TextButton.icon(
            onPressed: _addManually,
            icon: const Icon(Icons.edit),
            label: Text(l10n.addManually),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: l10n.searchPlaceholder,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: _onChanged,
              autofocus: true,
            ),
          ),
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
