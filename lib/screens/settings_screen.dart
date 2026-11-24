import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myroad/l10n/app_localizations.dart';
import 'package:myroad/services/locale_provider.dart';

/// Each language is named in itself, so it can be found from any UI language.
const _languages = <(Locale, String)>[
  (Locale('en'), 'English'),
  (Locale('zh'), '中文'),
  (Locale('ja'), '日本語'),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final current = _languages
        .where((e) => e.$1 == locale)
        .map((e) => e.$2)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(current ?? l10n.systemDefault),
            onTap: () => _pick(context, ref, locale),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    Locale? selected,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final options = <(Locale?, String)>[
      (null, l10n.systemDefault),
      ..._languages,
    ];
    // A record wrapper tells "System default" (null) from a dismissed dialog.
    final picked = await showDialog<(Locale?,)>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.language),
        children: [
          for (final (locale, name) in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, (locale,)),
              child: Row(
                children: [
                  Expanded(child: Text(name)),
                  if (locale == selected) const Icon(Icons.check),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) await ref.read(localeProvider.notifier).set(picked.$1);
  }
}
