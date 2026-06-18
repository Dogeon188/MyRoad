import 'package:flutter/material.dart';
import 'package:myroad/l10n/app_localizations.dart';

class RoiLibraryScreen extends StatelessWidget {
  const RoiLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Text(l10n.noRois),
    );
  }
}
