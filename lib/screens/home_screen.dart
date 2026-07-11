import 'package:flutter/material.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/screens/region_library/region_library_screen.dart';
import 'package:myroad/screens/trips/trip_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _screens = <Widget>[TripListScreen(), RegionLibraryScreen()];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.card_travel),
            label: l10n.trips,
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore),
            label: l10n.regionLibrary,
          ),
        ],
      ),
    );
  }
}
