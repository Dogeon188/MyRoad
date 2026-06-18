import 'package:flutter/material.dart';
import 'package:myroad/l10n/app_localizations.dart';

class TripListScreen extends StatelessWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Text(l10n.noTrips),
    );
  }
}
